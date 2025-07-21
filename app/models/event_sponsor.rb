# == Schema Information
#
# Table name: event_sponsors
#
#  id         :integer          not null, primary key
#  tier       :string
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  event_id   :integer          not null, indexed
#  sponsor_id :integer          not null, indexed
#
# Indexes
#
#  index_event_sponsors_on_event_id    (event_id)
#  index_event_sponsors_on_sponsor_id  (sponsor_id)
#
# Foreign Keys
#
#  event_id    (event_id => events.id)
#  sponsor_id  (sponsor_id => sponsors.id)
#
class EventSponsor < ApplicationRecord
  belongs_to :event
  belongs_to :sponsor
end
