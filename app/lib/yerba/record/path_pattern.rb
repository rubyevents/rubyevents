# frozen_string_literal: true

module Yerba
  module Record
    # A file path with named segments, like a route: "data/:series_id/:id/event.yml" or "thumbnails/:event_id/:video_id.webp"
    class PathPattern
      NAMED = /:(\w+)/

      attr_reader :pattern

      def initialize(pattern)
        @pattern = pattern.to_s
        @segments = @pattern.split("/")
      end

      def names
        @segments.flat_map { |segment| segment.scan(NAMED).flatten }.map(&:to_sym).uniq
      end

      def dynamic?
        @segments.any? { |segment| dynamic_segment?(segment) }
      end

      def wildcard?
        @segments.any? { |segment| segment.include?("*") }
      end

      # The leading directories before the first named segment or wildcard, like "data"
      def prefix
        @segments[0...-1].take_while { |segment| !dynamic_segment?(segment) }.join("/")
      end

      def glob
        @segments.map { |segment| segment.gsub(NAMED, "*") }.join("/")
      end

      def match(path)
        match = regexp.match(path.to_s)
        return nil unless match

        names.to_h { |name| [name, match[name.to_s]] }
      end

      # The directory the pattern starts in, like "/app" for "/app/data/rubyconf/rubyconf-2024/event.yml"
      def root_of(path)
        match = regexp.match(path.to_s)
        return nil unless match

        match.pre_match.delete_suffix("/").presence || "."
      end

      def expand_through(name, params)
        index = @segments.index(":#{name}")
        return nil unless index && index < @segments.size - 1

        PathPattern.new(@segments[0..index].join("/")).expand(params)
      end

      def expand(params)
        return nil if wildcard?

        expand_glob(params)
      end

      def expand_glob(params)
        segments = @segments.map do |segment|
          segment.gsub(NAMED) do
            value = params[Regexp.last_match(1).to_sym]
            return nil if value.blank?

            value.to_s
          end
        end

        segments.join("/")
      end

      def rewrite(path, params)
        match = regexp.match(path.to_s)
        return nil unless match

        rewritten = @segments.each_with_index.map do |segment, index|
          captured = match["_segment#{index}"]
          next captured if segment == "**"

          value = if segment.include?("*")
            captured
          else
            segment.gsub(NAMED) { params[Regexp.last_match(1).to_sym].presence || match[Regexp.last_match(1)] }
          end

          "#{value}/"
        end

        match.pre_match + rewritten.join.delete_suffix("/")
      end

      private

      def dynamic_segment?(segment)
        segment.match?(NAMED) || segment.include?("*")
      end

      def regexp
        @regexp ||= begin
          source = @segments.each_with_index.map do |segment, index|
            if segment == "**"
              "(?<_segment#{index}>(?:[^/]+/)*)"
            else
              "(?<_segment#{index}>#{segment_source(segment)})/"
            end
          end

          %r{(?:\A|(?<=/))#{source.join.delete_suffix("/")}\z}
        end
      end

      def segment_source(segment)
        segment.split(/(:\w+|\*)/).map do |part|
          name = part[/\A:(\w+)\z/, 1]

          if name
            "(?<#{name}>[^/]+?)"
          elsif part == "*"
            "[^/]*"
          else
            Regexp.escape(part)
          end
        end.join
      end
    end
  end
end
