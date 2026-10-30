require "guard/plugin"
require "fileutils"

module Guard
  class DataImport < Plugin
    def run_on_modifications(paths)
      process_paths(paths)
    end

    def run_on_additions(paths)
      process_paths(paths)
    end

    private

    def process_paths(paths)
      return if paths.empty?

      UI.info "Processing #{paths.size} file(s)..."

      success_count = 0

      paths.each do |path|
        success_count += 1 if import_for_path(path)
      end

      if success_count > 0
        trigger_vite_reload
        UI.info "Finished processing #{success_count} file(s)"
      end
    end

    def import_for_path(path)
      UI.info "File changed: #{path}"

      case path
      when "data/speakers.yml"
        import_speakers
      when "data/topics.yml"
        import_topics
      when "data/featured_cities.yml"
        import_featured_cities
      when %r{\Adata/.+/schedule\.yml\z}
        UI.info "Schedule file changed - no import action needed"

        true
      when %r{\Adata/.+/(series|event|videos|cfp|sponsors|involvements|venue)\.yml\z}
        directory = File.dirname(path)

        if File.exist?(File.join(directory, "series.yml"))
          import_series(File.join(directory, "series.yml"))
        else
          import_event(File.join(directory, "event.yml"))
        end
      else
        UI.warning "Unknown file pattern: #{path}"

        false
      end
    rescue => e
      UI.error "Error importing #{path}: #{e.message}"
      UI.error e.backtrace.first(5).join("\n")

      false
    end

    def import_speakers
      UI.info "Importing all speakers..."
      run_rails_runner("Static::Speaker.import_all!")
    end

    def import_topics
      UI.info "Importing all topics..."
      run_rails_runner("Static::Topic.import_all!")
    end

    def import_featured_cities
      UI.info "Importing all featured cities..."
      run_rails_runner("Static::FeaturedCity.import_all!")
    end

    def import_series(series_file)
      UI.info "Importing series: #{File.dirname(series_file)}"
      run_rails_runner("Static::EventSeries.find_by_file_path(Rails.root.join('#{series_file}'))&.import!")
    end

    def import_event(event_file)
      UI.info "Importing event: #{File.dirname(event_file)}"
      run_rails_runner("Static::Event.find_by_file_path(Rails.root.join('#{event_file}'))&.import!")
    end

    def run_rails_runner(code)
      system("bin/rails", "runner", code)
    end

    def trigger_vite_reload
      reload_file = File.join(Dir.pwd, "tmp", "vite-reload")
      FileUtils.mkdir_p(File.dirname(reload_file))
      FileUtils.touch(reload_file)

      UI.info "Triggered Vite reload"
    end
  end
end
