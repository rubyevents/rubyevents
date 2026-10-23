require "test_helper"

class Talk::TopicCandidatesTest < ActiveSupport::TestCase
  test "includes assigned approved topics but not rejected ones" do
    candidates = Talk::TopicCandidates.for(talks(:one))

    assert_includes candidates, topics(:one)
    assert_includes candidates, topics(:activerecord)
    assert_not_includes candidates, topics(:rejected)
  end

  test "includes approved topics mentioned in the talk, as whole words only" do
    hotwire = Topic.create!(name: "Hotwire", status: :approved)
    Topic.create!(name: "Wire", status: :approved)
    Topic.create!(name: "Frontend Patterns", status: :pending)

    candidates = Talk::TopicCandidates.for(talks(:one))

    assert_includes candidates, hotwire
    assert_not_includes candidates.map(&:name), "Wire"
    assert_not_includes candidates.map(&:name), "Frontend Patterns"
  end

  test "counts alias mentions toward the canonical topic" do
    turbo = Topic.create!(name: "Turbo", status: :approved)
    Topic.create!(name: "Live Updates", status: :duplicate, canonical: turbo)

    assert_includes Talk::TopicCandidates.for(talks(:one)), turbo
  end

  test "resolves assigned alias topics to their canonical topic" do
    rails = Topic.create!(name: "Ruby on Rails", status: :approved)
    topics(:activerecord).update!(canonical: rails)

    candidates = Talk::TopicCandidates.for(talks(:one))

    assert_includes candidates, rails
    assert_not_includes candidates, topics(:activerecord)
  end

  test "includes topics from the speakers' other talks" do
    talks(:three).topics << topics(:activerecord)

    assert_includes Talk::TopicCandidates.for(talks(:two)), topics(:activerecord)
  end
end
