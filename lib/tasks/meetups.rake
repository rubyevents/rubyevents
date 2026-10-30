namespace :meetups do
  desc "Split every meetup group's event into one event per meetup (DRY_RUN=1 to only report, ONLY=group-event-id,...)"
  task split: :environment do
    require "meetup_split"

    report = MeetupSplit.new(dry_run: ENV["DRY_RUN"].present?, only: ENV["ONLY"].to_s.split(",")).run

    report.each do |section, messages|
      puts "\n== #{section} (#{messages.size})"
      messages.each { |message| puts "  #{message}" }
    end
  end
end
