# frozen_string_literal: true

module Yerba
  module Record
    # A file path with named segments, like a route: "data/:series_id/:id/event.yml"
    class PathPattern
      NAMED_SEGMENT = /\A:(\w+)\z/

      attr_reader :pattern

      def initialize(pattern)
        @pattern = pattern.to_s
        @segments = @pattern.split("/")
      end

      def names
        @segments.filter_map { |segment| segment[NAMED_SEGMENT, 1]&.to_sym }
      end

      def dynamic?
        @segments.any? { |segment| dynamic_segment?(segment) }
      end

      # The leading directories before the first named segment or wildcard, like "data"
      def prefix
        @segments[0...-1].take_while { |segment| !dynamic_segment?(segment) }.join("/")
      end

      def glob
        @segments.map { |segment| segment.match?(NAMED_SEGMENT) ? "*" : segment }.join("/")
      end

      def match(path)
        regexp.match(path.to_s)&.named_captures&.transform_keys(&:to_sym)
      end

      # The directory the pattern starts in, like "/app" for "/app/data/rubyconf/rubyconf-2024/event.yml"
      def root_of(path)
        match = regexp.match(path.to_s)
        return nil unless match

        match.pre_match.delete_suffix("/").presence || "."
      end

      def expand(params)
        segments = @segments.map do |segment|
          return nil if segment.include?("*")

          name = segment[NAMED_SEGMENT, 1]
          next segment unless name

          value = params[name.to_sym]
          return nil if value.blank?

          value.to_s
        end

        segments.join("/")
      end

      private

      def dynamic_segment?(segment)
        segment.match?(NAMED_SEGMENT) || segment.include?("*")
      end

      def regexp
        @regexp ||= begin
          source = @segments.map do |segment|
            name = segment[NAMED_SEGMENT, 1]

            if name
              "(?<#{name}>[^/]+)/"
            elsif segment == "**"
              "(?:[^/]+/)*"
            else
              "#{Regexp.escape(segment).gsub("\\*", "[^/]*")}/"
            end
          end

          %r{(?:\A|(?<=/))#{source.join.delete_suffix("/")}\z}
        end
      end
    end
  end
end
