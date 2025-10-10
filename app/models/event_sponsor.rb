# == Schema Information
#
# Table name: event_sponsors
#
#  id         :integer          not null, primary key
#  badge      :string
#  tier       :string           uniquely indexed => [event_id, sponsor_id]
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  event_id   :integer          not null, indexed, uniquely indexed => [sponsor_id, tier]
#  sponsor_id :integer          not null, uniquely indexed => [event_id, tier], indexed
#
# Indexes
#
#  index_event_sponsors_on_event_id                   (event_id)
#  index_event_sponsors_on_event_sponsor_tier_unique  (event_id,sponsor_id,tier) UNIQUE
#  index_event_sponsors_on_sponsor_id                 (sponsor_id)
#
# Foreign Keys
#
#  event_id    (event_id => events.id)
#  sponsor_id  (sponsor_id => sponsors.id)
#
class EventSponsor < ApplicationRecord
  belongs_to :event
  belongs_to :sponsor

  validates :sponsor_id, uniqueness: {scope: [:event_id, :tier], message: "is already associated with this event for the same tier"}

  before_validation :normalize_tier

  private

  def normalize_tier
    self.tier = nil if tier.blank?
  end
end
