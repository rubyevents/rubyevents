class User::EmailVerification < ActiveRecord::AssociatedObject
  generates_token(expires_in: 2.days) { user.verified? }

  def verify!
    user.update! verified: true
  end

  def mailer = user.mailer.email_verification
  delegate :deliver_later, to: :mailer
end
