# == Schema Information
#
# Table name: event_involvements
# Database name: primary
#
#  id                   :integer          not null, primary key
#  ended_on             :date
#  involvementable_type :string           not null, uniquely indexed => [involvementable_id, event_id, role], indexed => [involvementable_id]
#  position             :integer          default(0)
#  role                 :string           not null, uniquely indexed => [involvementable_type, involvementable_id, event_id], indexed
#  started_on           :date
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  event_id             :integer          uniquely indexed => [involvementable_type, involvementable_id, role], indexed
#  event_series_id      :integer          indexed
#  involvementable_id   :integer          not null, uniquely indexed => [involvementable_type, event_id, role], indexed => [involvementable_type]
#
# Indexes
#
#  idx_involvements_on_involvementable_and_event_and_role  (involvementable_type,involvementable_id,event_id,role) UNIQUE
#  index_event_involvements_on_event_id                    (event_id)
#  index_event_involvements_on_event_series_id             (event_series_id)
#  index_event_involvements_on_involvementable             (involvementable_type,involvementable_id)
#  index_event_involvements_on_role                        (role)
#
# Foreign Keys
#
#  event_id         (event_id => events.id)
#  event_series_id  (event_series_id => event_series.id)
#
class EventInvolvement < ApplicationRecord
  # associations
  include SeriesOrEventOwned
  include Period

  belongs_to :involvementable, polymorphic: true

  # validations
  validates :involvementable_type, uniqueness: {scope: [:involvementable_id, :event_id, :role]}, if: :event_id?
  validates :role, presence: true

  def name
    "#{involvementable.name} - #{owner.name} - #{role}"
  end
end
