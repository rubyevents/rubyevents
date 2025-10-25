require "test_helper"

class ConnectedAccountTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
  end

  test "passport_accounts association" do
    @user.connected_accounts.create(provider: "passport", uid: "123456")
    assert_equal @user.passports.first.uid, "123456"
  end

  test "a user can have multiple passports" do
    assert_nothing_raised do
      @user.connected_accounts.create(provider: "passport", uid: "123456")
      @user.connected_accounts.create(provider: "passport", uid: "123457")
    end
  end

  test "a user can't have multiple passports with the same uid" do
    assert_raise do
      @user.connected_accounts.create(provider: "passport", uid: "123456")
      @user.connected_accounts.create(provider: "passport", uid: "123456")
    end
  end

  test "a user can have multiple github connected_accounts" do
    assert_nothing_raised do
      @user.connected_accounts.create!(provider: "github", uid: "123456")
      @user.connected_accounts.create!(provider: "github", uid: "123457")
    end
  end

  test "a user can have a passport and a github connected_account with teh same uid" do
    assert_nothing_raised do
      @user.connected_accounts.create(provider: "github", uid: "123456")
      @user.connected_accounts.create(provider: "passport", uid: "123456")
    end
  end
end
