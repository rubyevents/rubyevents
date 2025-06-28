require "test_helper"

class User::MailerTest < ActionMailer::TestCase
  setup do
    @user = users(:lazaro_nixon)
  end

  test "password_reset" do
    mail = @user.password_reset.mailer
    assert_equal "Reset your password", mail.subject
    assert_equal [@user.email], mail.to
  end

  test "email_verification" do
    mail = @user.email_verification.mailer
    assert_equal "Verify your email", mail.subject
    assert_equal [@user.email], mail.to
  end
end
