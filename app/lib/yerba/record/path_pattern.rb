# frozen_string_literal: true

module Yerba
  module Record
    # A file path with named segments, like a route: "data/:series_id/:id/event.yml" or "thumbnails/:event_id/:video_id.webp"
    #
    # A `*name` segment captures any number of directories, including none, like a route glob:
    # "data/*parent_path/:id/series.yml" matches both "data/rubyconf/series.yml" and "data/rails-girls/rails-girls-bern/series.yml".
    class PathPattern
      NAMED = /:(\w+)/
      SPLAT = /\A\*(\w+)\z/

      attr_reader :pattern

      def initialize(pattern)
        @pattern = pattern.to_s
        @segments = @pattern.split("/")
      end

      def names
        @segments.flat_map { |segment| splat_name(segment) ? [splat_name(segment)] : segment.scan(NAMED).flatten }.map(&:to_sym).uniq
      end

      def dynamic?
        @segments.any? { |segment| dynamic_segment?(segment) }
      end

      def wildcard?
        @segments.any? { |segment| wildcard_segment?(segment) }
      end

      def prefix
        @segments[0...-1].take_while { |segment| !dynamic_segment?(segment) }.join("/")
      end

      def glob
        @segments.map { |segment| splat_name(segment) ? "**" : segment.gsub(NAMED, "*") }.join("/")
      end

      def match(path)
        match = regexp.match(path.to_s)
        return nil unless match

        names.to_h { |name| [name, match[name.to_s].presence] }.compact
      end

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
        segments = @segments.filter_map do |segment|
          if (name = splat_name(segment))
            next params[name.to_sym].presence&.to_s
          end

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

          if (name = splat_name(segment))
            value = params.key?(name.to_sym) ? params[name.to_sym].to_s : match[name].to_s
            next value.empty? ? "" : "#{value}/"
          end

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

      def wildcard_segment?(segment)
        segment.include?("*") && !splat_name(segment)
      end

      def splat_name(segment)
        segment[SPLAT, 1]
      end

      def regexp
        @regexp ||= begin
          source = @segments.each_with_index.map do |segment, index|
            if segment == "**"
              "(?<_segment#{index}>(?:[^/]+/)*)"
            elsif (name = splat_name(segment))
              "(?<_segment#{index}>(?:(?<#{name}>[^/]+(?:/[^/]+)*)/)?)"
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
