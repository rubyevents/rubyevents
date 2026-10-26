# == Schema Information
#
# Table name: sponsors
# Database name: primary
#
#  id              :integer          not null, primary key
#  badge           :string
#  ended_on        :date
#  level           :integer
#  started_on      :date
#  tier            :string           uniquely indexed => [event_id, organization_id]
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  event_id        :integer          indexed, uniquely indexed => [organization_id, tier]
#  event_series_id :integer          indexed
#  organization_id :integer          not null, uniquely indexed => [event_id, tier], indexed
#
# Indexes
#
#  index_sponsors_on_event_id                        (event_id)
#  index_sponsors_on_event_organization_tier_unique  (event_id,organization_id,tier) UNIQUE
#  index_sponsors_on_event_series_id                 (event_series_id)
#  index_sponsors_on_organization_id                 (organization_id)
#
# Foreign Keys
#
#  event_id         (event_id => events.id)
#  event_series_id  (event_series_id => event_series.id)
#  organization_id  (organization_id => organizations.id)
#
class Sponsor < ApplicationRecord
  include SeriesOrEventOwned
  include Period

  belongs_to :organization

  validates :organization_id, uniqueness: {scope: [:event_id, :tier], message: "is already associated with this event for the same tier"}, if: :event_id?

  before_validation :normalize_tier

  private

  def normalize_tier
    self.tier = nil if tier.blank?
  end
end
