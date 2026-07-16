# frozen_string_literal: true

module Static
  module Validators
    class ExpectedDataFiles
      EXPECTED = {
        1 => %w[featured_cities.yml speakers.yml topics.yml],
        2 => %w[series.yml],
        3 => %w[cfp.yml event.yml involvements.yml schedule.yml sponsors.yml venue.yml videos.yml]
      }.freeze

      LOCATIONS = {
        1 => "data/",
        2 => "data/{series}/",
        3 => "data/{series}/{event}/"
      }.freeze

      def initialize(file_path:, document: nil)
        @file_path = file_path.to_s
      end

      def applicable?
        File.exist?(@file_path) && !File.directory?(@file_path) && segments.any?
      end

      def errors
        @errors ||= validate
      end

      def validate
        return [] unless applicable?

        filename = segments.last
        depth = segments.size

        return [] if EXPECTED[depth]&.include?(filename)

        [
          Static::Validators::Error.new(
            "Unexpected file '#{filename}' at data/#{segments.join("/")}, #{hint(filename, depth)}",
            file_path: @file_path,
            line: 1
          )
        ]
      end

      private

      def segments
        @segments ||= begin
          parts = File.expand_path(@file_path).split("/data/").last.to_s.split("/")

          (parts.join("/") == File.expand_path(@file_path)) ? [] : parts
        end
      end

      def hint(filename, depth)
        expected_depth = EXPECTED.find { |_depth, filenames| filenames.include?(filename) }&.first

        if expected_depth
          return "#{filename} files belong at #{LOCATIONS[expected_depth]}#{filename}"
        end

        suggestion = DidYouMean::SpellChecker.new(dictionary: EXPECTED.fetch(depth, [])).correct(filename).first

        if suggestion
          "did you mean '#{suggestion}'?"
        elsif EXPECTED.key?(depth)
          "expected one of: #{EXPECTED[depth].join(", ")}"
        else
          "no files are expected at this level"
        end
      end
    end
  end
end
