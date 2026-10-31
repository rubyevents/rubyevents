# == Schema Information
#
# Table name: subscriptions
# Database name: primary
#
#  id                :integer          not null, primary key
#  notes             :text
#  subscribable_type :string           not null, uniquely indexed => [user_id, subscribable_id], indexed => [subscribable_id]
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  subscribable_id   :integer          not null, uniquely indexed => [user_id, subscribable_type], indexed => [subscribable_type]
#  user_id           :integer          not null, uniquely indexed => [subscribable_type, subscribable_id], indexed
#
# Indexes
#
#  idx_on_user_id_subscribable_type_subscribable_id_fb68f3bd3a  (user_id,subscribable_type,subscribable_id) UNIQUE
#  index_subscriptions_on_subscribable                          (subscribable_type,subscribable_id)
#  index_subscriptions_on_user_id                               (user_id)
#
# Foreign Keys
#
#  user_id  (user_id => users.id)
#
class FavoriteUser < Subscription
  default_scope { where(subscribable_type: "User") }

  alias_attribute :favorite_user_id, :subscribable_id

  belongs_to :favorite_user, class_name: "User", foreign_key: :subscribable_id

  has_one :mutual_favorite_user, class_name: "FavoriteUser", primary_key: [:user_id, :subscribable_id], foreign_key: [:subscribable_id, :user_id]

  def ruby_friend?
    persisted? && mutual_favorite_user&.persisted?
  end

  # Returns the earliest upcoming event both the user and each favorite user are going to,
  # keyed by favorite user id
  def self.next_mutual_events_for(user, favorite_user_ids)
    EventParticipation
      .joins(:event).merge(Event.upcoming)
      .where(role: EventParticipation::GOING_ROLES)
      .where(user_id: favorite_user_ids, event_id: user.event_participations.where(role: EventParticipation::GOING_ROLES).select(:event_id))
      .preload(:event)
      .group_by(&:user_id)
      .transform_values { |participations| participations.first.event }
  end

  # Suggest favorite users based on talks the user has watched
  # No check for existing favorite users
  def self.recommendations_for(user)
    existing_favorite_ids = where(user: user).pluck(:favorite_user_id)

    recommended_user_ids = user
      .watched_talks.joins(talk: :speakers)
      .where.not(users: {id: [user.id, *existing_favorite_ids]})
      .distinct
      .limit(9)
      .pluck("users.id")

    User.where(id: recommended_user_ids).map do |recommended_user|
      FavoriteUser.new(user: user, favorite_user: recommended_user)
    end
  end
end
