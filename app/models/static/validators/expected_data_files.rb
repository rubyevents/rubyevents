# frozen_string_literal: true

module Static
  module Validators
    class ExpectedDataFiles
      EXPECTED = {
        root: %w[featured_cities.yml speakers.yml topics.yml],
        series: %w[series.yml cfp.yml involvements.yml sponsors.yml],
        event: %w[cfp.yml event.yml involvements.yml schedule.yml sponsors.yml venue.yml videos.yml]
      }.freeze

      LOCATIONS = {
        root: "data/",
        series: "data/{series}/",
        event: "data/{series}/{event}/"
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

        return [] if EXPECTED[level]&.include?(filename)

        [
          Static::Validators::Error.new(
            "Unexpected file '#{filename}' at data/#{segments.join("/")}, #{hint(filename)}",
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

      def level
        @level ||= begin
          file = File.expand_path(@file_path)
          directory = File.dirname(file)
          beside = ->(name) { (path = File.join(directory, name)) != file && File.exist?(path) }

          if segments.size == 1
            :root
          elsif beside.call("series.yml")
            :series
          elsif beside.call("event.yml")
            :event
          elsif segments.size == 2
            :series
          elsif File.exist?(File.join(File.dirname(directory), "series.yml"))
            (segments.last == "series.yml") ? :series : :event
          elsif segments.size == 3
            :event
          end
        end
      end

      def hint(filename)
        expected_level = EXPECTED.find { |_level, filenames| filenames.include?(filename) }&.first

        if expected_level
          return "#{filename} files belong at #{LOCATIONS[expected_level]}#{filename}"
        end

        suggestion = DidYouMean::SpellChecker.new(dictionary: EXPECTED.fetch(level, [])).correct(filename).first

        if suggestion
          "did you mean '#{suggestion}'?"
        elsif EXPECTED.key?(level)
          "expected one of: #{EXPECTED[level].join(", ")}"
        else
          "no files are expected at this level"
        end
      end
    end
  end
end
