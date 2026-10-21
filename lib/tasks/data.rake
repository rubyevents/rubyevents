namespace :data do
  desc "Show data/ files that differ from what's been imported (new / modified / deleted)"
  task status: :environment do
    changes = Static::DataImporter.changes

    if changes.empty?
      puts "All data files are in sync, nothing to import."
    else
      changes.group_by { |change| change[:status] }.each do |status, files|
        puts "#{status} (#{files.size}):"
        files.each { |change| puts "  #{change[:path]}" }
        puts
      end

      puts "Total: #{changes.size} #{"file".pluralize(changes.size)} out of sync."
    end
  end

  desc "Watch data/ for changes and incrementally import them in-process (uses Cruise)"
  task watch: :environment do
    require "cruise"

    data_root = Rails.root.join("data")

    trap("TERM") { exit(0) }

    puts "Watching #{data_root} for changes (Ctrl-C to stop)..."

    watcher = Cruise::Watcher.new(data_root.to_s, glob: "**/*.yml", only: %w[created modified renamed removed])
    paths = []

    begin
      loop do
        if watcher.io.wait_readable(paths.empty? ? nil : 0.2)
          break if watcher.io.read_nonblock(4096, exception: false).nil?

          while (message = watcher.poll_error)
            warn message
          end

          while (event = watcher.poll)
            paths << event.path
          end
        else
          begin
            Static::DataImporter.sync(paths)
          rescue => e
            warn "error syncing data: #{e.class}: #{e.message}"
          end

          paths = []
        end
      end
    rescue Interrupt
      puts "\nStopped watching."
    ensure
      watcher.close
    end
  end
end
