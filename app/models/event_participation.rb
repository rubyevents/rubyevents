# == Schema Information
#
# Table name: event_participations
# Database name: primary
#
#  id         :integer          not null, primary key
#  role       :string           not null, indexed
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  event_id   :integer          not null, uniquely indexed => [user_id], indexed
#  user_id    :integer          not null, uniquely indexed => [event_id], indexed
#
# Indexes
#
#  index_event_participations_on_event_id              (event_id)
#  index_event_participations_on_role                  (role)
#  index_event_participations_on_user_id               (user_id)
#  index_event_participations_on_user_id_and_event_id  (user_id,event_id) UNIQUE
#
# Foreign Keys
#
#  event_id  (event_id => events.id)
#  user_id   (user_id => users.id)
#
class EventParticipation < ApplicationRecord
  GOING_ROLES = %w[speaker attendee].freeze

  # associations
  belongs_to :user
  belongs_to :event

  # validations
  validates :user_id, uniqueness: {scope: :event_id}

  # enums - ordered from highest to lowest rank
  enum :role, %w[speaker attendee interested].index_by(&:itself), validate: true

  # scopes
  scope :going, -> { where(role: GOING_ROLES) }

  def self.record(user:, event:, role:)
    participation = find_or_initialize_by(user:, event:)
    participation.role = role if participation.new_record? || participation.outranked_by?(role)
    participation.save!
    participation
  end

  def name
    "#{user.name} - #{event.name} - #{role}"
  end

  def going?
    GOING_ROLES.include?(role)
  end

  def outranked_by?(other_role)
    self.class.roles.keys.index(other_role.to_s) < self.class.roles.keys.index(role)
  end
end
