require "test_helper"

class AliasTest < ActiveSupport::TestCase
  test "can create an alias for a user" do
    user = User.create!(name: "Test User", github_handle: "test-user-alias")
    alias_record = user.aliases.create!(name: "Alias Name", slug: "alias-name")

    assert_equal "Alias Name", alias_record.name
    assert_equal "alias-name", alias_record.slug
    assert_equal user, alias_record.aliasable
  end

  test "requires name to be present" do
    user = User.create!(name: "Test User", github_handle: "test-user-alias-2")
    alias_record = user.aliases.build(slug: "test-slug")

    assert_not alias_record.valid?
    assert_includes alias_record.errors[:name], "can't be blank"
  end

  test "slug is optional" do
    user = User.create!(name: "Test User", github_handle: "test-user-alias-3")
    alias_record = user.aliases.build(name: "Test Name", slug: nil)

    assert alias_record.valid?
  end

  test "slug must be globally unique across all aliasable types" do
    user1 = User.create!(name: "User One", github_handle: "user-one-alias")
    user2 = User.create!(name: "User Two", github_handle: "user-two-alias")

    user1.aliases.create!(name: "Name One", slug: "shared-slug")
    alias2 = user2.aliases.build(name: "Name Two", slug: "shared-slug")

    assert_not alias2.valid?
    assert_includes alias2.errors[:slug], "has already been taken"
  end

  test "same aliasable can have multiple aliases with the same slug" do
    user = User.create!(name: "Test User", github_handle: "user-slug-reuse")
    user.aliases.create!(name: "Name Variant One", slug: "same-slug")
    alias2 = user.aliases.build(name: "Name Variant Two", slug: "same-slug")

    assert alias2.valid?
    alias2.save!

    assert_equal 2, user.aliases.where(slug: "same-slug").count
  end

  test "name must be unique per aliasable_type" do
    user1 = User.create!(name: "User One", github_handle: "test-user-alias-4")
    user2 = User.create!(name: "User Two", github_handle: "test-user-alias-5")

    user1.aliases.create!(name: "Duplicate Name", slug: "slug-one")
    alias2 = user2.aliases.build(name: "Duplicate Name", slug: "slug-two")

    assert_not alias2.valid?
    assert_includes alias2.errors[:name], "has already been taken"
  end

  test "same name can be used for different aliasable types" do
    user = User.create!(name: "User One", github_handle: "user-one-alias-2")
    user_alias = user.aliases.create!(name: "Shared Name", slug: "slug-user-one")

    assert user_alias.valid?
    assert_equal "Shared Name", user_alias.name
  end

  test "slug must be unique even when different aliasable types have the same id" do
    user = User.create!(name: "Test User", github_handle: "user-same-id-test")
    event_series = EventSeries.create!(name: "Test Series", slug: "test-series-same-id")

    user.aliases.create!(name: "User Alias", slug: "globally-unique-slug")
    series_alias = event_series.aliases.build(name: "Series Alias", slug: "globally-unique-slug")

    assert_not series_alias.valid?
    assert_includes series_alias.errors[:slug], "has already been taken"
  end

  test "same aliasable cannot have duplicate names" do
    user = User.create!(name: "Test User", github_handle: "user-duplicate-name")
    user.aliases.create!(name: "Same Name", slug: "slug-one")
    alias2 = user.aliases.build(name: "Same Name", slug: "slug-two")

    assert_not alias2.valid?
    assert_includes alias2.errors[:name], "has already been taken"
  end

  test "polymorphic association works with different types" do
    user = User.create!(name: "Test User", github_handle: "test-user-alias-6")
    user_alias = user.aliases.create!(name: "User Alias", slug: "user-alias-poly")

    assert_equal "User", user_alias.aliasable_type
    assert_equal user.id, user_alias.aliasable_id
    assert_equal user, user_alias.aliasable
  end
end
