# rubocop:disable Layout/LineLength
# == Schema Information
#
# Table name: watch_lists
# Database name: primary
#
#  id          :integer          not null, primary key
#  description :text
#  name        :string           not null
#  talks_count :integer          default(0)
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  user_id     :integer          not null, indexed
#
# Indexes
#
#  index_watch_lists_on_user_id  (user_id)
#
# rubocop:enable Layout/LineLength
class WatchList < ApplicationRecord
  belongs_to :user
  has_many :watch_list_talks, dependent: :destroy
  has_many :talks, through: :watch_list_talks

  validates :name, presence: true
end
