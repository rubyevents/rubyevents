class User::PasswordReset < ActiveRecord::AssociatedObject
  generates_token(expires_in: 20.minutes) { user.password_salt.last(10) }

  def valid?
    user.verified?
  end

  def reset(params)
    if (success = user.update(params))
      user.password_reset_tokens.delete_all # TODO: Remove password_reset_tokens table
      success
    end
  end

  def mailer = user.mailer.password_reset
  delegate :deliver_later, to: :mailer
end
