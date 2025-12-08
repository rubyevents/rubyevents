class Recurring::RollupJob < ApplicationJob
  queue_as :low

  def perform(*args)
    # first we remove suspicious visits
    cleanup_suspicious_recent_visits

    # then we rollup the visits and events
    Ahoy::Visit.rollup("ahoy_visits", interval: :day)
    Ahoy::Visit.rollup("ahoy_visits", interval: :month)
    Ahoy::Event.rollup("ahoy_events", interval: :day)
    Ahoy::Event.rollup("ahoy_events", interval: :month)
    Talk.rollup("talks", interval: :year, column: :date)
  end

  def cleanup_suspicious_recent_visits
    # Find IPs with more than 50 visits in the last 3 days
    suspicious_ips = Ahoy::Visit
      .where(started_at: 3.day.ago..)
      .group(:ip)
      .having("COUNT(*) > 50")
      .pluck(:ip)

    if suspicious_ips.any?
      visits = Ahoy::Visit.where(ip: suspicious_ips)

      Ahoy::Event.where(visit_id: visits.select(:id)).delete_all
      visits.delete_all
    end
  end
end
