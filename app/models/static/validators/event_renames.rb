# frozen_string_literal: true

module Static
  module Validators
    class EventRenames
      include GitBaseline

      PATTERNS = [
        "**/event.yml"
      ].freeze

      def initialize(file_path:, document: nil)
        @file_path = file_path
        @document = document
      end

      def applicable?
        return false unless File.exist?(@file_path)

        PATTERNS.any? do |pattern|
          File.fnmatch?(pattern, @file_path, File::FNM_PATHNAME | File::FNM_DOTMATCH)
        end
      end

      def errors
        @errors ||= validate
      end

      def validate
        return [] if disappeared_ids.empty?

        location = event.source_location("id")
        previous = disappeared_ids.map { %("#{it}") }.join(", ")

        [
          Static::Validators::Error.new(
            %(event "#{event["id"]}" is new, while #{previous} from main is gone from this series. If "#{event["id"]}" was renamed, keep the previous id in `old_ids` so production moves the event and its old URLs redirect. Run `bin/rails validate:fix` to add it.),
            file_path: @file_path,
            line: location&.start_line || 1,
            end_line: location&.end_line
          )
        ]
      end

      def fix
        return unless disappeared_ids.one? && new_events_in_series.one?

        event["old_ids"] = event.old_ids + disappeared_ids
        event.save!

        {changed: 1, file_path: @file_path}
      end

      private

      def event
        @event ||= Static::Event.in_file(@file_path.to_s, document: @document).first
      end

      def series_directory
        File.dirname(File.expand_path(@file_path.to_s), 2)
      end

      # Event ids of this series on the baseline that no event has anymore, neither as
      # its id nor in its old_ids.
      def disappeared_ids
        @disappeared_ids ||= begin
          return [] unless applicable? && changed_since_baseline? && event && new_event?

          series = File.basename(series_directory)
          baseline_ids = self.class.baseline_event_directories.select { |_id, directories| directories.any? { File.basename(File.dirname(it)) == series } }.keys

          baseline_ids - known_ids
        end
      end

      def new_event?
        event.old_ids.empty? && self.class.baseline_file(relative_path).nil?
      end

      def known_ids
        Static::Event.all.flat_map { [it["id"], *it.old_ids] }.compact
      end

      def new_events_in_series
        Dir[File.join(series_directory, "*", "event.yml")].select do |path|
          sibling = Static::Event.in_file(path).first
          sibling && sibling.old_ids.empty? && self.class.baseline_file(path.sub("#{Rails.root}/", "")).nil?
        end
      end
    end
  end
end
