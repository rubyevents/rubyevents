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

    begin
      Cruise.watch(data_root.to_s, glob: "**/*.yml", only: %w[created modified renamed removed]) do |event|
        relative = ImportedFile.relative_path(event.path)

        if event.kind == "removed"
          ImportedFile.forget!(relative)
          puts "removed #{relative}"
          next
        end

        next unless ImportedFile.changed?(relative)

        puts "changed #{relative}"

        if Static::DataImporter.import(relative, reload: true)
          ImportedFile.record!(relative)
          puts "imported #{relative}"
        end
      rescue => e
        warn "error importing #{event.path}: #{e.message}"
      end
    rescue Interrupt
      puts "\nStopped watching."
    end
  end
end
