require "guard/plugin"
require "fileutils"

module Guard
  class DataImport < Plugin
    def run_on_modifications(paths)
      paths.each do |path|
        import_for_path(path)
      end
    end

    def run_on_additions(paths)
      paths.each do |path|
        import_for_path(path)
      end
    end

    private

    def import_for_path(path)
      UI.info "File changed: #{path}"

      case path
      when "data/speakers.yml"
        import_speakers
      when "data/topics.yml"
        import_topics
      when "data/videos_to_ignore.yml"
        reload_ignored_videos
      when %r{^data/([^/]+)/series\.yml$}
        import_series($1)
      when %r{^data/([^/]+)/([^/]+)/event\.yml$}
        import_event($1, $2)
      when %r{^data/([^/]+)/([^/]+)/videos\.yml$}
        import_videos($1, $2)
      when %r{^data/([^/]+)/([^/]+)/cfp\.yml$}
        import_cfps($1, $2)
      when %r{^data/([^/]+)/([^/]+)/sponsors\.yml$}
        import_sponsors($1, $2)
      when %r{^data/([^/]+)/([^/]+)/schedule\.yml$}
        UI.info "Schedule file changed - no import action needed"
      else
        UI.warning "Unknown file pattern: #{path}"
      end
    rescue => e
      UI.error "Error importing #{path}: #{e.message}"
      UI.error e.backtrace.first(5).join("\n")
    end

    def import_speakers
      UI.info "Importing all speakers..."
      run_rails_runner("Static::Speaker.import_all!")
    end

    def import_topics
      UI.info "Importing all topics..."
      run_rails_runner("Static::Topic.import_all!")
    end

    def reload_ignored_videos
      UI.info "Reloading ignored videos list..."
      run_rails_runner("Static::IgnoredVideo.reload")
    end

    def import_series(series_slug)
      UI.info "Importing series: #{series_slug}"
      run_rails_runner("Static::EventSeries.find_by_slug('#{series_slug}')&.import!")
    end

    def import_event(series_slug, event_slug)
      UI.info "Importing event: #{series_slug}/#{event_slug}"
      run_rails_runner("Static::Event.find_by_slug('#{event_slug}')&.import!")
    end

    def import_videos(series_slug, event_slug)
      UI.info "Importing videos for: #{series_slug}/#{event_slug}"
      run_rails_runner(<<~RUBY)
        event = Event.find_by(slug: '#{event_slug}')
        if event
          Static::Event.find_by_slug('#{event_slug}')&.import_videos!(event)
        else
          puts "Event '#{event_slug}' not found in database. Import event first."
        end
      RUBY
    end

    def import_cfps(series_slug, event_slug)
      UI.info "Importing CFPs for: #{series_slug}/#{event_slug}"
      run_rails_runner(<<~RUBY)
        event = Event.find_by(slug: '#{event_slug}')
        if event
          Static::Event.find_by_slug('#{event_slug}')&.import_cfps!(event)
        else
          puts "Event '#{event_slug}' not found in database. Import event first."
        end
      RUBY
    end

    def import_sponsors(series_slug, event_slug)
      UI.info "Importing sponsors for: #{series_slug}/#{event_slug}"
      run_rails_runner(<<~RUBY)
        event = Event.find_by(slug: '#{event_slug}')
        if event
          Static::Event.find_by_slug('#{event_slug}')&.import_sponsors!(event)
        else
          puts "Event '#{event_slug}' not found in database. Import event first."
        end
      RUBY
    end

    def run_rails_runner(code)
      success = system("bin/rails", "runner", code)
      trigger_vite_reload if success
      success
    end

    def trigger_vite_reload
      reload_file = File.join(Dir.pwd, "tmp", "vite-reload")
      FileUtils.mkdir_p(File.dirname(reload_file))
      FileUtils.touch(reload_file)
      UI.info "Triggered Vite reload"
    end
  end
end
