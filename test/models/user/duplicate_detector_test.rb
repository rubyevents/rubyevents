require "test_helper"

class User::DuplicateDetectorTest < ActiveSupport::TestCase
  test "reversed_name returns name parts in reverse order" do
    user = User.create!(name: "John Smith")

    assert_equal "Smith John", user.duplicate_detector.reversed_name
  end

  test "reversed_name handles single word names" do
    user = User.create!(name: "Yukihiro")

    assert_equal "Yukihiro", user.duplicate_detector.reversed_name
  end

  test "reversed_name handles three word names" do
    user = User.create!(name: "Mary Jane Watson")

    assert_equal "Watson Jane Mary", user.duplicate_detector.reversed_name
  end

  test "reversed_name returns nil for blank name" do
    user = User.create!(name: "Test User")
    user.update_column(:name, "")

    assert_nil user.duplicate_detector.reversed_name
  end

  test "normalized_name returns sorted lowercase name parts" do
    user = User.create!(name: "John Smith")

    assert_equal "john smith", user.duplicate_detector.normalized_name
  end

  test "normalized_name is same for reversed names" do
    user1 = User.create!(name: "John Smith")
    user2 = User.create!(name: "Smith John")

    assert_equal user1.duplicate_detector.normalized_name,
      user2.duplicate_detector.normalized_name
  end

  test "potential_duplicates_by_reversed_name finds reversed name matches" do
    user1 = User.create!(name: "John Smith")
    user2 = User.create!(name: "Smith John")

    duplicates = user1.duplicate_detector.potential_duplicates_by_reversed_name

    assert_includes duplicates, user2
  end

  test "potential_duplicates_by_reversed_name finds matches with different capitalization" do
    user1 = User.create!(name: "Masafumi OKURA")
    user2 = User.create!(name: "Okura Masafumi")

    duplicates = user1.duplicate_detector.potential_duplicates_by_reversed_name

    assert_includes duplicates, user2
  end

  test "potential_duplicates_by_reversed_name excludes self" do
    user = User.create!(name: "John Smith")

    duplicates = user.duplicate_detector.potential_duplicates_by_reversed_name

    assert_not_includes duplicates, user
  end

  test "potential_duplicates_by_reversed_name excludes canonical aliases" do
    canonical = User.create!(name: "John Smith")
    alias_user = User.create!(name: "Smith John", canonical_id: canonical.id)

    duplicates = canonical.duplicate_detector.potential_duplicates_by_reversed_name

    assert_not_includes duplicates, alias_user
  end

  test "potential_duplicates_by_reversed_name excludes marked for deletion" do
    user1 = User.create!(name: "John Smith")
    user2 = User.create!(name: "Smith John", marked_for_deletion: true)

    duplicates = user1.duplicate_detector.potential_duplicates_by_reversed_name

    assert_not_includes duplicates, user2
  end

  test "potential_duplicates_by_reversed_name returns none for blank name" do
    user = User.create!(name: "Test User")
    user.update_column(:name, "")

    assert_empty user.duplicate_detector.potential_duplicates_by_reversed_name
  end

  test "has_reversed_name_duplicate? returns true when duplicate exists" do
    user1 = User.create!(name: "John Smith")
    User.create!(name: "Smith John")

    assert user1.duplicate_detector.has_reversed_name_duplicate?
  end

  test "has_reversed_name_duplicate? returns false when no duplicate" do
    user = User.create!(name: "John Smith")

    assert_not user.duplicate_detector.has_reversed_name_duplicate?
  end

  test "find_all_reversed_name_duplicates finds all duplicate pairs" do
    User.create!(name: "John Smith")
    User.create!(name: "Smith John")
    User.create!(name: "Jane Doe")
    User.create!(name: "Doe Jane")

    duplicates = User::DuplicateDetector.find_all_reversed_name_duplicates

    assert_equal 2, duplicates.count
  end

  test "find_all_reversed_name_duplicates finds pairs with different capitalization" do
    user1 = User.create!(name: "Masafumi OKURA")
    user2 = User.create!(name: "Okura Masafumi")

    duplicates = User::DuplicateDetector.find_all_reversed_name_duplicates

    assert_equal 1, duplicates.count
    pair = duplicates.first
    assert_includes pair, user1
    assert_includes pair, user2
  end

  test "find_all_reversed_name_duplicates skips palindromic names" do
    User.create!(name: "Ali Ali")

    duplicates = User::DuplicateDetector.find_all_reversed_name_duplicates

    assert_empty duplicates
  end

  test "find_all_reversed_name_duplicates returns unique pairs" do
    user1 = User.create!(name: "John Smith")
    user2 = User.create!(name: "Smith John")

    duplicates = User::DuplicateDetector.find_all_reversed_name_duplicates

    # Should only return one pair, not two
    assert_equal 1, duplicates.count
    pair = duplicates.first
    assert_includes pair, user1
    assert_includes pair, user2
  end

  test "find_all_reversed_name_duplicates excludes canonical users" do
    canonical = User.create!(name: "John Smith")
    User.create!(name: "Smith John", canonical_id: canonical.id)

    duplicates = User::DuplicateDetector.find_all_reversed_name_duplicates

    assert_empty duplicates
  end

  test "find_all_reversed_name_duplicates excludes marked for deletion" do
    User.create!(name: "John Smith")
    User.create!(name: "Smith John", marked_for_deletion: true)

    duplicates = User::DuplicateDetector.find_all_reversed_name_duplicates

    assert_empty duplicates
  end

  test "report returns message when no duplicates" do
    report = User::DuplicateDetector.report

    assert_equal "No duplicates found.", report
  end

  test "report returns formatted output when duplicates exist" do
    User.create!(name: "John Smith", talks_count: 5, github_handle: "johnsmith")
    User.create!(name: "Smith John", talks_count: 0)

    report = User::DuplicateDetector.report

    assert_includes report, "Reversed Name Duplicates"
    assert_includes report, "John Smith"
    assert_includes report, "Smith John"
    assert_includes report, "talks=5"
    assert_includes report, "github=johnsmith"
  end

  test "with_reversed_name_duplicate scope returns users with duplicates" do
    user1 = User.create!(name: "John Smith")
    user2 = User.create!(name: "Smith John")
    User.create!(name: "No Duplicate")

    users_with_duplicates = User.with_reversed_name_duplicate

    assert_includes users_with_duplicates, user1
    assert_includes users_with_duplicates, user2
    assert_equal 2, users_with_duplicates.count
  end

  test "with_reversed_name_duplicate scope excludes users without duplicates" do
    User.create!(name: "Unique Name")

    users_with_duplicates = User.with_reversed_name_duplicate

    assert_empty users_with_duplicates
  end

  test "with_reversed_name_duplicate scope excludes canonical users" do
    canonical = User.create!(name: "John Smith")
    User.create!(name: "Smith John", canonical_id: canonical.id)

    users_with_duplicates = User.with_reversed_name_duplicate

    assert_not_includes users_with_duplicates, canonical
  end

  test "with_reversed_name_duplicate scope finds matches with different capitalization" do
    user1 = User.create!(name: "Masafumi OKURA")
    user2 = User.create!(name: "Okura Masafumi")

    users_with_duplicates = User.with_reversed_name_duplicate

    assert_includes users_with_duplicates, user1
    assert_includes users_with_duplicates, user2
  end
end
