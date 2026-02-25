# == Schema Information
#
# Table name: favorite_users
# Database name: primary
#
#  id               :integer          not null, primary key
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  favorite_user_id :integer          not null, indexed
#  user_id          :integer          not null, indexed
#
# Indexes
#
#  index_favorite_users_on_favorite_user_id  (favorite_user_id)
#  index_favorite_users_on_user_id           (user_id)
#
# Foreign Keys
#
#  favorite_user_id  (favorite_user_id => users.id)
#  user_id           (user_id => users.id)
#
class FavoriteUser < ApplicationRecord
  belongs_to :user
  belongs_to :favorite_user, class_name: "User"

  validates :user, comparison: {other_than: :favorite_user}
  validates :favorite_user_id, uniqueness: {scope: :user_id}

  has_one :mutual_favorite_user, class_name: "FavoriteUser", primary_key: [:user_id, :favorite_user_id], foreign_key: [:favorite_user_id, :user_id]

  def ruby_friend?
    persisted? && mutual_favorite_user&.persisted?
  end

  # Suggest favorite users based on talks the user has watched
  # No check for existing favorite users
  def self.recommendations_for(user)
    recommended_user_ids = user
      .watched_talks.joins(talk: :speakers)
      .where.not(users: {id: user.id})
      .distinct
      .limit(6)
      .pluck("users.id")

    recommended_users = User.where(id: recommended_user_ids)
    recommended_users
      .map do |recommended_user|
        FavoriteUser.new(user: user, favorite_user: recommended_user)
      end
  end
end
