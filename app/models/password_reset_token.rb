# rubocop:disable Layout/LineLength
# == Schema Information
#
# Table name: password_reset_tokens
# Database name: primary
#
#  id      :integer          not null, primary key
#  user_id :integer          not null, indexed
#
# Indexes
#
#  index_password_reset_tokens_on_user_id  (user_id)
#
# Foreign Keys
#
#  user_id  (user_id => users.id)
#
# rubocop:enable Layout/LineLength
class PasswordResetToken < ApplicationRecord
  belongs_to :user
end
