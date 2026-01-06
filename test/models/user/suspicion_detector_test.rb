require "test_helper"

class User::SuspicionDetectorTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  test "suspicious? returns false for unverified users" do
    user = User.create!(
      name: "Unverified User",
      github_handle: "unverified-test",
      bio: "Check out https://spam.com",
      talks_count: 0,
      watched_talks_count: 0,
      github_metadata: {
        "profile" => {
          "created_at" => 1.day.ago.iso8601,
          "public_repos" => 0,
          "followers" => 0,
          "following" => 0
        }
      }
    )

    assert_not user.verified?
    assert_not user.suspicious?
  end

  test "suspicious? returns false for verified user with few signals" do
    user = User.create!(
      name: "Legit User",
      github_handle: "legit-user-test",
      bio: "Ruby developer",
      talks_count: 5,
      watched_talks_count: 10,
      github_metadata: {
        "profile" => {
          "created_at" => 2.years.ago.iso8601,
          "public_repos" => 50,
          "followers" => 100,
          "following" => 50
        }
      }
    )
    user.connected_accounts.create!(provider: "github", uid: "12345")

    assert user.verified?
    assert_not user.suspicious?
  end

  test "suspicious? returns true for verified user with 3+ signals" do
    user = User.create!(
      name: "Spam User",
      github_handle: "spam-user-test",
      bio: "Buy trailers at https://spam.com",
      talks_count: 0,
      watched_talks_count: 0,
      github_metadata: {
        "profile" => {
          "created_at" => 1.month.ago.iso8601,
          "public_repos" => 0,
          "followers" => 0,
          "following" => 0
        }
      }
    )
    user.connected_accounts.create!(provider: "github", uid: "67890")

    assert user.verified?
    assert user.suspicious?
  end

  test "suspicious? returns false for verified user with exactly 2 signals" do
    user = User.create!(
      name: "Edge Case User",
      github_handle: "edge-case-test",
      bio: "Normal bio without URLs",
      talks_count: 0,
      watched_talks_count: 0,
      github_metadata: {
        "profile" => {
          "created_at" => 1.year.ago.iso8601,
          "public_repos" => 10,
          "followers" => 5,
          "following" => 5
        }
      }
    )
    user.connected_accounts.create!(provider: "github", uid: "11111")

    assert user.verified?
    assert_not user.suspicious?
  end

  test "github_account_newer_than? returns true for new account" do
    user = User.create!(
      name: "New GitHub User",
      github_metadata: {"profile" => {"created_at" => 1.month.ago.iso8601}}
    )

    assert user.github_account_newer_than?(6.months)
  end

  test "github_account_newer_than? returns false for old account" do
    user = User.create!(
      name: "Old GitHub User",
      github_metadata: {"profile" => {"created_at" => 2.years.ago.iso8601}}
    )

    assert_not user.github_account_newer_than?(6.months)
  end

  test "github_account_newer_than? returns false when metadata blank" do
    user = User.create!(name: "No Metadata User", github_metadata: {})

    assert_not user.github_account_newer_than?(6.months)
  end

  test "suspicion_detector.github_account_empty? returns true when all counts are zero" do
    user = User.create!(
      name: "Empty GitHub User",
      github_metadata: {
        "profile" => {
          "public_repos" => 0,
          "followers" => 0,
          "following" => 0
        }
      }
    )

    assert user.suspicion_detector.github_account_empty?
  end

  test "suspicion_detector.github_account_empty? returns false when has repos" do
    user = User.create!(
      name: "Active GitHub User",
      github_metadata: {
        "profile" => {
          "public_repos" => 5,
          "followers" => 0,
          "following" => 0
        }
      }
    )

    assert_not user.suspicion_detector.github_account_empty?
  end

  test "suspicion_detector.github_account_empty? returns false when has followers" do
    user = User.create!(
      name: "Popular GitHub User",
      github_metadata: {
        "profile" => {
          "public_repos" => 0,
          "followers" => 10,
          "following" => 0
        }
      }
    )

    assert_not user.suspicion_detector.github_account_empty?
  end

  test "suspicion_detector.github_account_empty? returns false when metadata blank" do
    user = User.create!(name: "No Metadata User 2", github_metadata: {})

    assert_not user.suspicion_detector.github_account_empty?
  end

  test "suspicion_detector.bio_contains_url? returns true when bio has http URL" do
    user = User.create!(name: "URL Bio User", bio: "Check out http://example.com")

    assert user.suspicion_detector.bio_contains_url?
  end

  test "suspicion_detector.bio_contains_url? returns true when bio has https URL" do
    user = User.create!(name: "HTTPS Bio User", bio: "Visit https://example.com for more")

    assert user.suspicion_detector.bio_contains_url?
  end

  test "suspicion_detector.bio_contains_url? returns false for normal bio" do
    user = User.create!(name: "Normal Bio User", bio: "Ruby developer from Berlin")

    assert_not user.suspicion_detector.bio_contains_url?
  end

  test "suspicion_detector.bio_contains_url? returns false for blank bio" do
    user = User.create!(name: "Blank Bio User", bio: "")

    assert_not user.suspicion_detector.bio_contains_url?
  end

  test "cleared? returns false when cleared_at is nil" do
    user = User.create!(name: "Uncleared User", cleared_at: nil)

    assert_not user.cleared?
  end

  test "cleared? returns true when cleared_at is present" do
    user = User.create!(name: "Cleared User", cleared_at: Time.current)

    assert user.cleared?
  end

  test "clear! sets cleared_at to current time" do
    user = User.create!(name: "User To Clear")

    assert_nil user.cleared_at

    user.clear!

    assert_not_nil user.cleared_at
    assert user.cleared?
  end

  test "unclear! resets cleared_at to nil" do
    user = User.create!(name: "User To Unclear", cleared_at: Time.current)

    assert user.cleared?

    user.unclear!

    assert_nil user.cleared_at
    assert_not user.cleared?
  end

  test "suspicious? returns false for cleared user even with suspicious signals" do
    user = User.create!(
      name: "Cleared Spam User",
      github_handle: "cleared-spam-test",
      bio: "Buy stuff at https://spam.com",
      talks_count: 0,
      watched_talks_count: 0,
      cleared_at: Time.current,
      github_metadata: {
        "profile" => {
          "created_at" => 1.month.ago.iso8601,
          "public_repos" => 0,
          "followers" => 0,
          "following" => 0
        }
      }
    )
    user.connected_accounts.create!(provider: "github", uid: "cleared123")

    assert user.verified?
    assert user.cleared?
    assert_not user.suspicious?
  end

  test "suspicious? returns true for uncleared user with suspicious signals" do
    user = User.create!(
      name: "Uncleared Spam User",
      github_handle: "uncleared-spam-test",
      bio: "Buy stuff at https://spam.com",
      talks_count: 0,
      watched_talks_count: 0,
      cleared_at: nil,
      github_metadata: {
        "profile" => {
          "created_at" => 1.month.ago.iso8601,
          "public_repos" => 0,
          "followers" => 0,
          "following" => 0
        }
      }
    )
    user.connected_accounts.create!(provider: "github", uid: "uncleared123")

    assert user.verified?
    assert_not user.cleared?
    assert user.suspicious?
  end

  test "suspicious? returns false for user with passport even with suspicious signals" do
    user = User.create!(
      name: "Passport User",
      github_handle: "passport-user-test",
      bio: "Buy stuff at https://spam.com",
      talks_count: 0,
      watched_talks_count: 0,
      github_metadata: {
        "profile" => {
          "created_at" => 1.month.ago.iso8601,
          "public_repos" => 0,
          "followers" => 0,
          "following" => 0
        }
      }
    )
    user.connected_accounts.create!(provider: "github", uid: "passport123")
    user.connected_accounts.create!(provider: "passport", uid: "ruby-passport-123")

    assert user.verified?
    assert user.passports.any?
    assert_not user.suspicious?
  end
end
