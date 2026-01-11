require "test_helper"

class UKNationTest < ActiveSupport::TestCase
  test "initialize creates UKNation with correct attributes" do
    nation = UKNation.new("scotland")

    assert_equal "scotland", nation.slug
    assert_equal "SCT", nation.state_code
    assert_equal "Scotland", nation.nation_name
  end

  test "name returns nation name" do
    nation = UKNation.new("scotland")

    assert_equal "Scotland", nation.name
  end

  test "alpha2 returns GB prefixed state code" do
    nation = UKNation.new("scotland")

    assert_equal "GB-SCT", nation.alpha2
  end

  test "code returns gb for all UK nations" do
    %w[england scotland wales northern-ireland].each do |slug|
      nation = UKNation.new(slug)

      assert_equal "gb", nation.code, "Expected code to be 'gb' for #{slug}"
    end
  end

  test "code is compatible with 2-letter alpha2 route constraints" do
    nation = UKNation.new("scotland")

    assert_match(/\A[a-z]{2}\z/, nation.code)
  end

  test "path returns countries path with slug" do
    nation = UKNation.new("scotland")

    assert_equal "/countries/scotland", nation.path
  end

  test "to_param returns slug" do
    nation = UKNation.new("scotland")

    assert_equal "scotland", nation.to_param
  end

  test "continent returns Europe" do
    nation = UKNation.new("scotland")

    assert_equal "Europe", nation.continent
  end

  test "continent_name returns Europe" do
    nation = UKNation.new("scotland")

    assert_equal "Europe", nation.continent_name
  end

  test "cities returns ActiveRecord::Relation for GB cities in nation" do
    nation = UKNation.new("england")

    assert nation.cities.is_a?(ActiveRecord::Relation)
  end

  test "emoji_flag returns GB flag" do
    nation = UKNation.new("scotland")

    assert_equal "\u{1F1EC}\u{1F1E7}", nation.emoji_flag
  end

  test "uk_nation? returns true" do
    nation = UKNation.new("scotland")

    assert nation.uk_nation?
  end

  test "parent_country returns GB Country" do
    nation = UKNation.new("scotland")

    assert_equal "GB", nation.parent_country.alpha2
  end

  test "two UKNations with same slug are equal" do
    nation1 = UKNation.new("scotland")
    nation2 = UKNation.new("scotland")

    assert_equal nation1, nation2
  end

  test "two UKNations with different slugs are not equal" do
    nation1 = UKNation.new("scotland")
    nation2 = UKNation.new("england")

    assert_not_equal nation1, nation2
  end

  test "UKNation is not equal to Country" do
    nation = UKNation.new("scotland")
    country = Country.find_by(country_code: "GB")

    assert_not_equal nation, country
  end

  test "eql? returns true for nations with same slug" do
    nation1 = UKNation.new("scotland")
    nation2 = UKNation.new("scotland")

    assert nation1.eql?(nation2)
  end

  test "hash is same for nations with same slug" do
    nation1 = UKNation.new("scotland")
    nation2 = UKNation.new("scotland")

    assert_equal nation1.hash, nation2.hash
  end

  test "nations can be used as hash keys" do
    nation1 = UKNation.new("scotland")
    nation2 = UKNation.new("scotland")

    hash = {nation1 => "value"}

    assert_equal "value", hash[nation2]
  end

  test "events returns events matching GB country_code and state" do
    nation = UKNation.new("scotland")

    assert nation.events.is_a?(ActiveRecord::Relation)
  end

  test "users returns users matching GB country_code and state" do
    nation = UKNation.new("scotland")

    assert nation.users.is_a?(ActiveRecord::Relation)
  end

  test "stamps" do
    nation = UKNation.new("scotland")

    assert_equal 1, nation.stamps.length
    assert_equal "GB-SCT", nation.stamps.first.code
  end

  test "held_in_sentence returns sentence with nation name" do
    nation = UKNation.new("scotland")

    assert_equal " held in Scotland", nation.held_in_sentence
  end

  test "all UK nations can be created" do
    nations = Country::UK_NATIONS.keys.map { |slug| UKNation.new(slug) }

    assert_equal 4, nations.size
    assert_equal %w[England Northern\ Ireland Scotland Wales], nations.map(&:name).sort
  end

  test "to_location returns Location with nation and Europe" do
    nation = UKNation.new("scotland")
    location = nation.to_location

    assert_kind_of Location, location
    assert_equal "Scotland, United Kingdom", location.to_text
  end

  test "to_location for all UK nations includes Europe" do
    Country::UK_NATIONS.keys.each do |slug|
      nation = UKNation.new(slug)
      location = nation.to_location

      assert_includes location.to_text, ", United Kingdom", "Expected #{nation.name} to include United Kingdom"
      assert_not_includes location.to_text, ", Europe", "Expected #{nation.name} to not include Europe"
    end
  end
end
