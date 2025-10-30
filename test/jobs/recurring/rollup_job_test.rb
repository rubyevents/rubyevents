require "test_helper"

class Recurring::RollupJobTest < ActiveJob::TestCase
  test "creates rollups for visits and events" do
    visit_1 = Ahoy::Visit.create!(started_at: Time.current)
    Ahoy::Event.create!(name: "Some Page during visit_1", visit: visit_1, time: Time.current)

    Recurring::RollupJob.new.perform

    assert_equal 1, Rollup.where(name: "ahoy_visits", interval: :day).count
    assert_equal 1, Rollup.where(name: "ahoy_visits", interval: :month).count
    assert_equal 1, Rollup.where(name: "ahoy_events", interval: :day).count
    assert_equal 1, Rollup.where(name: "ahoy_events", interval: :month).count
  end

  test "cleans up suspicious visits before rollup" do
    # Create a suspicious IP with many visits
    suspicious_ip = "192.168.1.1"
    60.times do
      visit = Ahoy::Visit.create!(started_at: 2.days.ago, ip: suspicious_ip)
      Ahoy::Event.create!(name: "Page View", visit: visit, time: 2.days.ago)
    end

    # Create a normal visit
    normal_visit = Ahoy::Visit.create!(started_at: 2.days.ago, ip: "192.168.1.2")

    initial_visit_count = Ahoy::Visit.count
    initial_event_count = Ahoy::Event.count

    Recurring::RollupJob.new.perform

    # Suspicious visits should be removed
    assert Ahoy::Visit.count < initial_visit_count
    assert Ahoy::Event.count < initial_event_count

    # Normal visit should remain
    assert Ahoy::Visit.exists?(normal_visit.id)
  end
end
