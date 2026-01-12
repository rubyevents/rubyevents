namespace :backfill do
  desc "Backfill Event Involvements records from involvements.yml files"
  task event_involvements: :environment do
    puts "Starting backfill of event involvement records from YAML files..."

    events_processed = 0
    error_count = 0

    Static::Event.all.each do |static_event|
      next unless static_event.event_record.involvements_file.exist?

      events_processed += 1
      print "."

      static_event.import_involvements!(static_event.event_record)
    rescue => e
      puts "\nError processing event #{static_event.slug}: #{e.message}"
      error_count += 1
    end

    puts "\n\nBackfill completed!"
    puts "Events processed: #{events_processed}"
    puts "Errors: #{error_count}"
  end
end
