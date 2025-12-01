# == Schema Information
#
# Table name: sponsors
# Database name: primary
#
#  id              :integer          not null, primary key
#  badge           :string
#  tier            :string           uniquely indexed => [event_id, organization_id]
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  event_id        :integer          not null, indexed, uniquely indexed => [organization_id, tier]
#  organization_id :integer          not null, uniquely indexed => [event_id, tier], indexed
#
# Indexes
#
#  index_sponsors_on_event_id                        (event_id)
#  index_sponsors_on_event_organization_tier_unique  (event_id,organization_id,tier) UNIQUE
#  index_sponsors_on_organization_id                 (organization_id)
#
# Foreign Keys
#
#  event_id         (event_id => events.id)
#  organization_id  (organization_id => organizations.id)
#
class Sponsor < ApplicationRecord
  belongs_to :event
  belongs_to :organization

  validates :organization_id, uniqueness: {scope: [:event_id, :tier], message: "is already associated with this event for the same tier"}

  before_validation :normalize_tier

  private

  def normalize_tier
    self.tier = nil if tier.blank?
  end
end
