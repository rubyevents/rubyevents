# rubocop:disable Layout/LineLength
# == Schema Information
#
# Table name: sessions
# Database name: primary
#
#  id         :integer          not null, primary key
#  ip_address :string
#  user_agent :string
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  user_id    :integer          not null, indexed
#
# Indexes
#
#  index_sessions_on_user_id  (user_id)
#
# Foreign Keys
#
#  user_id  (user_id => users.id)
#
# rubocop:enable Layout/LineLength
class Session < ApplicationRecord
  belongs_to :user, inverse_of: :sessions

  before_create do
    self.user_agent = Current.user_agent
    self.ip_address = Current.ip_address
  end

  def sign_out_siblings!
    user.sessions.without(self).delete_all
  end
end
