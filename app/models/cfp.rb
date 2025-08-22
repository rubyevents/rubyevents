# == Schema Information
#
# Table name: cfps
#
#  id         :integer          not null, primary key
#  close_date :date
#  link       :string
#  name       :string
#  open_date  :date
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  event_id   :integer          not null, indexed
#
# Indexes
#
#  index_cfps_on_event_id  (event_id)
#
# Foreign Keys
#
#  event_id  (event_id => events.id)
#
class CFP < ApplicationRecord
  belongs_to :event
end
