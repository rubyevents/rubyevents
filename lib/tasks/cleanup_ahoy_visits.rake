namespace :ahoy do
  desc "Delete Ahoy visits from IPs with more than 200 visits"
  task cleanup_suspicious_visits: :environment do
    # Find IPs with more than 200 visits
    suspicious_ips = Ahoy::Visit
      .group(:ip)
      .having("COUNT(*) > 200")
      .pluck(:ip)

    if suspicious_ips.any?
      puts "Found #{suspicious_ips.count} IPs with suspicious activity"

      # Delete all visits from those IPs
      events_count = Ahoy::Event.where(visit_id: Ahoy::Visit.where(ip: suspicious_ips).select(:id)).delete_all
      deleted_count = Ahoy::Visit.where(ip: suspicious_ips).delete_all

      puts "Successfully deleted #{deleted_count} visits and #{events_count} events"
    else
      puts "No suspicious IP activity found"
    end
  end
end
