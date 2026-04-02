# == Schema Information
#
# Table name: notifications
# Database name: primary
#
#  id         :integer          not null, primary key
#  name       :string
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
class Notification < ApplicationRecord
  validates :name, presence: true, uniqueness: true
end
