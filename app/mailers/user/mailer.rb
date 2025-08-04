class User::Mailer < ApplicationMailer
  before_action { @user = params[:user] }
  before_action { @token = @user.public_send(action_name).token }

  def password_reset
    mail to: @user.email, subject: "Reset your password"
  end

  def email_verification
    mail to: @user.email, subject: "Verify your email"
  end
end
