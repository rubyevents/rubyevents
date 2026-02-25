class Recurring::RollupJob < ApplicationJob
  queue_as :low

  BATCH_SIZE = 500
  VISIT_THRESHOLD = 50

  def perform(*args)
    # first we remove suspicious visits in batches to avoid long locks
    cleanup_suspicious_recent_visits

    # then we rollup the visits and events
    Ahoy::Visit.rollup("ahoy_visits", interval: :day)
    Ahoy::Visit.rollup("ahoy_visits", interval: :month)
    Ahoy::Event.rollup("ahoy_events", interval: :day)
    Ahoy::Event.rollup("ahoy_events", interval: :month)
    Talk.rollup("talks", interval: :year, column: :date)
  end

  def cleanup_suspicious_recent_visits
    # Find IPs with more than threshold visits in the last 3 days
    # Process one IP at a time to keep transactions short
    suspicious_ips = find_suspicious_ips

    suspicious_ips.each do |ip|
      delete_visits_for_ip_in_batches(ip)
    end
  end

  private

  def find_suspicious_ips
    # Use a more efficient query that leverages the index on started_at
    Ahoy::Visit
      .where(started_at: 3.days.ago..)
      .where.not(ip: nil)
      .group(:ip)
      .having("COUNT(*) > ?", VISIT_THRESHOLD)
      .pluck(:ip)
  end

  def delete_visits_for_ip_in_batches(ip)
    loop do
      # Find a batch of visit IDs for this IP
      visit_ids = Ahoy::Visit
        .where(ip: ip)
        .limit(BATCH_SIZE)
        .pluck(:id)

      break if visit_ids.empty?

      # Delete events first (foreign key dependency)
      Ahoy::Event.where(visit_id: visit_ids).delete_all

      # Then delete visits
      Ahoy::Visit.where(id: visit_ids).delete_all

      # Allow other queries to run between batches
      sleep(0.1) if visit_ids.size == BATCH_SIZE
    end
  end
end
