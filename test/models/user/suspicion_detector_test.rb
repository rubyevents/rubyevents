require "test_helper"

class User::SuspicionDetectorTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  test "calculate_suspicious? returns false for unverified users" do
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
    assert_not user.suspicion_detector.calculate_suspicious?
  end

  test "calculate_suspicious? returns false for verified user with few signals" do
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
    assert_not user.suspicion_detector.calculate_suspicious?
  end

  test "calculate_suspicious? returns true for verified user with 3+ signals" do
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
    assert user.suspicion_detector.calculate_suspicious?
  end

  test "calculate_suspicious? returns false for verified user with exactly 2 signals" do
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
    assert_not user.suspicion_detector.calculate_suspicious?
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

  test "suspicion_cleared? returns false when suspicion_cleared_at is nil" do
    user = User.create!(name: "Uncleared User", suspicion_cleared_at: nil)

    assert_not user.suspicion_cleared?
  end

  test "suspicion_cleared? returns true when suspicion_cleared_at is present" do
    user = User.create!(name: "Cleared User", suspicion_cleared_at: Time.current)

    assert user.suspicion_cleared?
  end

  test "clear_suspicion! sets suspicion_cleared_at and clears suspicion_marked_at" do
    user = User.create!(name: "User To Clear", suspicion_marked_at: Time.current)

    assert_nil user.suspicion_cleared_at
    assert_not_nil user.suspicion_marked_at

    user.clear_suspicion!

    assert_not_nil user.suspicion_cleared_at
    assert_nil user.suspicion_marked_at
    assert user.suspicion_cleared?
    assert_not user.suspicious?
  end

  test "unclear_suspicion! resets suspicion_cleared_at to nil" do
    user = User.create!(name: "User To Unclear", suspicion_cleared_at: Time.current)

    assert user.suspicion_cleared?

    user.unclear_suspicion!

    assert_nil user.suspicion_cleared_at
    assert_not user.suspicion_cleared?
  end

  test "mark_suspicious! returns true and sets suspicion_marked_at when signals match" do
    user = User.create!(
      name: "Spam User",
      github_handle: "mark-suspicious-true",
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
    user.connected_accounts.create!(provider: "github", uid: "mark-true-123")

    assert_nil user.suspicion_marked_at
    assert user.mark_suspicious!
    assert_not_nil user.suspicion_marked_at
  end

  test "mark_suspicious! returns false and does not set suspicion_marked_at when signals do not match" do
    user = User.create!(
      name: "Legit User",
      github_handle: "mark-suspicious-false",
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
    user.connected_accounts.create!(provider: "github", uid: "mark-false-123")

    assert_nil user.suspicion_marked_at
    assert_not user.mark_suspicious!
    assert_nil user.suspicion_marked_at
  end

  test "suspicious? returns true when suspicion_marked_at is set and not cleared" do
    user = User.create!(name: "Marked User", suspicion_marked_at: Time.current)

    assert user.suspicious?
  end

  test "suspicious? returns false when suspicion_marked_at is nil" do
    user = User.create!(name: "Unmarked User", suspicion_marked_at: nil)

    assert_not user.suspicious?
  end

  test "suspicious? returns false when marked but also cleared" do
    user = User.create!(
      name: "Marked And Cleared User",
      suspicion_marked_at: Time.current,
      suspicion_cleared_at: Time.current
    )

    assert_not user.suspicious?
  end

  test "calculate_suspicious? returns false for cleared user even with suspicious signals" do
    user = User.create!(
      name: "Cleared Spam User",
      github_handle: "cleared-spam-test",
      bio: "Buy stuff at https://spam.com",
      talks_count: 0,
      watched_talks_count: 0,
      suspicion_cleared_at: Time.current,
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
    assert user.suspicion_cleared?
    assert_not user.suspicion_detector.calculate_suspicious?
  end

  test "calculate_suspicious? returns true for uncleared user with suspicious signals" do
    user = User.create!(
      name: "Uncleared Spam User",
      github_handle: "uncleared-spam-test",
      bio: "Buy stuff at https://spam.com",
      talks_count: 0,
      watched_talks_count: 0,
      suspicion_cleared_at: nil,
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
    assert_not user.suspicion_cleared?
    assert user.suspicion_detector.calculate_suspicious?
  end

  test "suspicious scope returns only users with suspicion_marked_at and no suspicion_cleared_at" do
    suspicious_user = User.create!(name: "Suspicious", suspicion_marked_at: Time.current)
    cleared_user = User.create!(name: "Cleared", suspicion_marked_at: Time.current, suspicion_cleared_at: Time.current)
    normal_user = User.create!(name: "Normal")

    suspicious_users = User.suspicious

    assert_includes suspicious_users, suspicious_user
    assert_not_includes suspicious_users, cleared_user
    assert_not_includes suspicious_users, normal_user
  end

  test "not_suspicious scope returns users without suspicion_marked_at or with suspicion_cleared_at" do
    suspicious_user = User.create!(name: "Suspicious", suspicion_marked_at: Time.current)
    cleared_user = User.create!(name: "Cleared", suspicion_marked_at: Time.current, suspicion_cleared_at: Time.current)
    normal_user = User.create!(name: "Normal")

    not_suspicious_users = User.not_suspicious

    assert_not_includes not_suspicious_users, suspicious_user
    assert_includes not_suspicious_users, cleared_user
    assert_includes not_suspicious_users, normal_user
  end

  test "suspicion_cleared scope returns only users with suspicion_cleared_at" do
    cleared_user = User.create!(name: "Cleared", suspicion_cleared_at: Time.current)
    not_cleared_user = User.create!(name: "Not Cleared")

    cleared_users = User.suspicion_cleared

    assert_includes cleared_users, cleared_user
    assert_not_includes cleared_users, not_cleared_user
  end

  test "suspicion_not_cleared scope returns only users without suspicion_cleared_at" do
    cleared_user = User.create!(name: "Cleared", suspicion_cleared_at: Time.current)
    not_cleared_user = User.create!(name: "Not Cleared")

    not_cleared_users = User.suspicion_not_cleared

    assert_not_includes not_cleared_users, cleared_user
    assert_includes not_cleared_users, not_cleared_user
  end

  test "calculate_suspicious? returns false for user with passport even with suspicious signals" do
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
    assert_not user.suspicion_detector.calculate_suspicious?
  end
end
