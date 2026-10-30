# frozen_string_literal: true

module Static
  module Validators
    class IdMatchesFolder
      def initialize(file_path:, document: nil)
        @file_path = file_path
        @document = document
      end

      PATTERNS = [
        "**/event.yml",
        "**/series.yml"
      ].freeze

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
        return [] unless applicable?

        folder_name = File.basename(File.dirname(@file_path))
        id = record["id"]
        location = record.source_location("id")

        if id.nil? || id.to_s.strip.empty?
          [
            Static::Validators::Error.new(
              "id is required and must match the folder name \"#{folder_name}\" at /id",
              file_path: @file_path,
              line: location&.start_line || 1,
              end_line: location&.end_line
            )
          ]
        elsif id.to_s != folder_name
          [
            Static::Validators::Error.new(
              "id \"#{id}\" does not match the folder name \"#{folder_name}\" at /id",
              file_path: @file_path,
              line: location&.start_line || 1,
              end_line: location&.end_line
            )
          ]
        else
          []
        end
      end

      private

      def record
        model = (File.basename(@file_path.to_s) == "series.yml") ? Static::EventSeries : Static::Event

        @record ||= model.in_file(@file_path.to_s, document: @document).first
      end
    end
  end
end
