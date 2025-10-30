class Recurring::RollupJob < ApplicationJob
  include ActiveJob::Continuable

  queue_as :low

  def perform(*args)
    step :cleanup_suspicious_visits do
      cleanup_suspicious_recent_visits
    end

    step :rollup_visits_daily do
      Ahoy::Visit.rollup("ahoy_visits", interval: :day)
    end

    step :rollup_visits_monthly do
      Ahoy::Visit.rollup("ahoy_visits", interval: :month)
    end

    step :rollup_events_daily do
      Ahoy::Event.rollup("ahoy_events", interval: :day)
    end

    step :rollup_events_monthly do
      Ahoy::Event.rollup("ahoy_events", interval: :month)
    end

    step :rollup_talks_yearly do
      Talk.rollup("talks", interval: :year, column: :date)
    end
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
