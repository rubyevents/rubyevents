# == Schema Information
#
# Table name: event_participations
# Database name: primary
#
#  id          :integer          not null, primary key
#  attended_as :string           not null, uniquely indexed => [user_id, event_id], indexed
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  event_id    :integer          not null, uniquely indexed => [user_id, attended_as], indexed
#  user_id     :integer          not null, uniquely indexed => [event_id, attended_as], indexed
#
# Indexes
#
#  idx_on_user_id_event_id_attended_as_ca0a2916e2  (user_id,event_id,attended_as) UNIQUE
#  index_event_participations_on_attended_as       (attended_as)
#  index_event_participations_on_event_id          (event_id)
#  index_event_participations_on_user_id           (user_id)
#
# Foreign Keys
#
#  event_id  (event_id => events.id)
#  user_id   (user_id => users.id)
#
class EventParticipation < ApplicationRecord
  # associations
  belongs_to :user
  belongs_to :event

  # validations
  validates :user_id, uniqueness: {scope: [:event_id, :attended_as]}

  # enums
  enum :attended_as, %w[keynote_speaker speaker visitor].index_by(&:itself), prefix: true

  def name
    "#{user.name} - #{event.name} - #{attended_as}"
  end
end
