# rubocop:disable Layout/LineLength
# == Schema Information
#
# Table name: connected_accounts
# Database name: primary
#
#  id           :integer          not null, primary key
#  access_token :string
#  expires_at   :datetime
#  provider     :string           uniquely indexed => [uid], uniquely indexed => [username]
#  uid          :string           uniquely indexed => [provider]
#  username     :string           uniquely indexed => [provider]
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  user_id      :integer          not null, indexed
#
# Indexes
#
#  index_connected_accounts_on_provider_and_uid       (provider,uid) UNIQUE
#  index_connected_accounts_on_provider_and_username  (provider,username) UNIQUE
#  index_connected_accounts_on_user_id                (user_id)
#
# Foreign Keys
#
#  user_id  (user_id => users.id)
#
# rubocop:enable Layout/LineLength
class ConnectedAccount < ApplicationRecord
  belongs_to :user

  encrypts :access_token

  normalizes :username, with: ->(value) { value.strip.downcase }

  enum :provider, ["developer", "github", "passport"].index_by(&:itself)
end
