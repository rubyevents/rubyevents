# frozen_string_literal: true

require "generators/venue/venue_generator"

module Static
  module Validators
    class DefaultVenue
      def initialize(file_path:)
        @file_path = file_path
      end

      PATTERNS = [
        "**/venue.yml"
      ].freeze

      # Placeholder values that the venue generator leaves behind and that a
      # contributor is expected to replace. Most are sourced directly from the
      # generator's class_options (so they can't drift), but a few placeholders
      # live only in the template (lib/generators/venue/templates/venue.yml.tt)
      # or come from the geocode-failed path, so they're listed explicitly here.
      TEMPLATE_DEFAULTS = {
        "instructions" => ["Instructions for getting to the venue - Optional"],
        "url" => ["Venue website url - Optional"]
      }.freeze

      EXTRA_DEFAULTS = {
        "name" => ["TODO"]
      }.freeze

      def applicable?
        return false unless File.exist?(@file_path)

        PATTERNS.any? do |pattern|
          File.fnmatch?(pattern, @file_path, File::FNM_PATHNAME)
        end
      end

      def errors
        @errors ||= validate
      end

      def validate
        return [] unless applicable?

        document = Yerba.parse_file(@file_path)
        errors = []

        default_values.each do |field, defaults|
          value = document[field]
          next if value.nil?

          if defaults.include?(value.to_s.strip)
            errors << build_error(
              "#{field} is still set to the default placeholder value (#{value.to_s.strip.inspect}). Replace it with the real venue #{field}.",
              location: value.location,
              pointer: "/#{field}"
            )
          end
        end

        address = document["address"]
        display = address && address["display"]
        if display && address_display_defaults.include?(display.to_s.strip)
          errors << build_error(
            "address.display is still set to the default placeholder value (#{display.to_s.strip.inspect}). Replace it with the real venue address.",
            location: display.location,
            pointer: "/address/display"
          )
        end

        errors
      end

      private

      # Merge the generator's option-backed defaults (name, description, url)
      # with the template-only and extra placeholders.
      def default_values
        @default_values ||= begin
          options = VenueGenerator.class_options
          option_defaults = {
            "name" => [options[:name].default],
            "description" => [options[:description].default],
            "url" => [options[:url].default]
          }

          [option_defaults, TEMPLATE_DEFAULTS, EXTRA_DEFAULTS].each_with_object(Hash.new { |h, k| h[k] = [] }) do |source, merged|
            source.each { |field, values| merged[field].concat(values) }
          end
        end
      end

      def address_display_defaults
        [VenueGenerator.class_options[:address].default]
      end

      def build_error(message, location:, pointer:)
        Static::Validators::Error.new(
          "#{message} at #{pointer}",
          file_path: @file_path,
          line: location&.start_line || 1,
          end_line: location&.end_line
        )
      end
    end
  end
end
