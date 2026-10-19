# frozen_string_literal: true

module Static
  module Validators
    # Events link to cities by [city, country_code, state_code], so an event without a
    # state ("Sendai, Japan") doesn't show up on a city page whose City record has one
    # ("Sendai, Miyagi, Japan"). Same-named cities in different states are left alone.
    class EventCityStateConsistency
      PATTERNS = ["**/event.yml"].freeze

      def initialize(file_path:, document: nil)
        @file_path = file_path.to_s.sub("#{Rails.root}/", "")
      end

      def applicable?
        return false unless File.exist?(@file_path)

        PATTERNS.any? do |pattern|
          File.fnmatch?(pattern, @file_path, File::FNM_PATHNAME | File::FNM_DOTMATCH)
        end
      end

      def errors
        return [] unless applicable?

        self.class.errors.select { |error| error.file_path == @file_path }
      end

      def self.errors
        events = Static::Event.all
        return @errors if @events.equal?(events)

        @events = events
        @errors = inconsistency_errors(events)
      end

      def self.warmup
        errors
      end

      def self.inconsistency_errors(events)
        groups = events.select { |event| event.resolved_city.present? && event.country.present? }
          .group_by { |event| [event.resolved_city.downcase, event.country.alpha2] }

        groups.values.flat_map do |group|
          stateless, with_state = group.partition { |event| event.state_code.blank? }
          next [] if stateless.empty? || with_state.empty?

          suggestions = with_state.map(&:location).tally.sort_by { |_location, count| -count }.map(&:first)

          stateless.map do |event|
            location = event.source_location("location")

            Static::Validators::Error.new(
              %(Location "#{event.location}" has no state, but other events in this city use #{suggestions.map { |s| %("#{s}") }.join(" or ")}. Mixed formats keep events off the city page.),
              file_path: event.file_path.to_s.sub("#{Rails.root}/", ""),
              line: location&.start_line || 1,
              end_line: location&.end_line
            )
          end
        end
      end
    end
  end
end
