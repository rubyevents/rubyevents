# == Schema Information
#
# Table name: event_involvements
#
#  id                    :integer          not null, primary key
#  involvementable_type  :string           not null, indexed => [involvementable_id, event_id, role]
#  role                  :string           not null, indexed, indexed => [involvementable_type, involvementable_id, event_id]
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#  event_id              :integer          not null, indexed, indexed => [involvementable_type, involvementable_id, role]
#  involvementable_id    :integer          not null, indexed => [involvementable_type, event_id, role]
#
# Indexes
#
#  idx_involvements_on_involvementable_and_event_and_role  (involvementable_type,involvementable_id,event_id,role) UNIQUE
#  index_event_involvements_on_event_id                    (event_id)
#  index_event_involvements_on_involvementable             (involvementable_type,involvementable_id)
#  index_event_involvements_on_role                        (role)
#
# Foreign Keys
#
#  event_id  (event_id => events.id)
#
class EventInvolvement < ApplicationRecord
  # associations
  belongs_to :involvementable, polymorphic: true
  belongs_to :event

  # validations
  validates :involvementable_type, uniqueness: {scope: [:involvementable_id, :event_id, :role]}
  validates :role, presence: true

  def name
    "#{involvementable.name} - #{event.name} - #{role}"
  end
end
