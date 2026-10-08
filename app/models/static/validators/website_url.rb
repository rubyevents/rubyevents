# frozen_string_literal: true

module Static
  module Validators
    class WebsiteURL
      PATTERNS = [
        "**/speakers.yml"
      ].freeze

      DISALLOWED_HOSTS = %w[
        t.co
        twitter.com
        x.com
      ].freeze

      def initialize(file_path:, document: nil)
        @file_path = file_path
        @document = document
      end

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

        disallowed_websites(document.value_at("")).map do |selector, website|
          location = document[selector]&.location

          Static::Validators::Error.new(
            %(website "#{website}" points to t.co, twitter.com or x.com, use the actual website instead (Twitter/X handles belong in the "twitter" field)),
            file_path: @file_path,
            line: location&.start_line || 1,
            end_line: location&.end_line
          )
        end
      end

      def self.disallowed?(url)
        host = URI.parse(url.to_s.strip).host.to_s.downcase
        return false if host.empty?

        DISALLOWED_HOSTS.any? { |disallowed| host == disallowed || host.end_with?(".#{disallowed}") }
      rescue URI::InvalidURIError
        false
      end

      private

      def document
        @document ||= Yerba.parse_file(@file_path.to_s)
      end

      def disallowed_websites(value, path = nil)
        case value
        when Hash
          value.flat_map do |key, nested|
            selector = [path, key].compact.join(".")

            if key == "website" && nested.is_a?(String)
              self.class.disallowed?(nested) ? [[selector, nested]] : []
            else
              disallowed_websites(nested, selector)
            end
          end
        when Array
          value.each_with_index.flat_map { |nested, index| disallowed_websites(nested, "#{path}[#{index}]") }
        else
          []
        end
      end
    end
  end
end
