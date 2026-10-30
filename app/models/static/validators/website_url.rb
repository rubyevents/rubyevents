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

        speakers.filter_map do |speaker|
          website = speaker["website"]
          next unless website.is_a?(String) && self.class.disallowed?(website)

          location = speaker.source_location("website")

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

      def speakers
        @speakers ||= Static::Speaker.in_file(@file_path.to_s, document: @document).to_a
      end
    end
  end
end
