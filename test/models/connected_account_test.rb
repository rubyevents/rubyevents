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

  test "passport uid is upcased so it matches event check-in connect_ids" do
    account = @user.connected_accounts.create!(provider: "passport", uid: " 5780ea ")
    assert_equal "5780EA", account.uid
  end

  test "non-passport uid casing is left untouched" do
    account = @user.connected_accounts.create!(provider: "github", uid: "AbC123")
    assert_equal "AbC123", account.uid
  end

  test "claiming a passport backfills participations for existing check-ins" do
    event = events(:future_conference)
    EventCheckIn.create!(connect_id: "PASS123", event: event, checked_in_at: Time.current)

    assert_difference -> { @user.event_participations.count }, 1 do
      @user.connected_accounts.create!(provider: "passport", uid: "PASS123")
    end

    assert @user.event_participations.find_by(event: event).attended_as_visitor?
  end

  test "claiming a passport does not duplicate existing participations" do
    event = events(:future_conference)
    EventCheckIn.create!(connect_id: "PASS123", event: event, checked_in_at: Time.current)
    @user.event_participations.create!(event: event, attended_as: :speaker)

    assert_no_difference -> { @user.event_participations.count } do
      @user.connected_accounts.create!(provider: "passport", uid: "PASS123")
    end
  end
end
