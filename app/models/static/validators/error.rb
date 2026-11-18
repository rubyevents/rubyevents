module Static
  module Validators
    class Error
      attr_reader :message, :file_path, :line, :end_line, :column, :end_column

      def initialize(message, file_path:, location: nil, line: nil, end_line: nil, column: nil, end_column: nil)
        @message = message
        @file_path = file_path.sub("#{Rails.root}/", "")
        @line = line || location&.start_line || 1
        @end_line = end_line || location&.end_line || @line
        @column = column || location&.start_column || 1
        @end_column = end_column || location&.end_column || @column
      end

      def to_h
        {
          "message" => message,
          "file_path" => file_path,
          "line" => line,
          "end_line" => end_line,
          "column" => column,
          "end_column" => end_column
        }
      end

      def as_error
        if ENV["GITHUB_ACTIONS"] == "true"
          GitHubAnnotation.error(annotation_message, **annotation_properties)
        elsif line > 1
          "❌ line #{line}: #{message}"
        else
          "❌ #{message}"
        end
      end

      def as_warning
        if ENV["GITHUB_ACTIONS"] == "true"
          GitHubAnnotation.warning(annotation_message, **annotation_properties)
        elsif line > 1
          "⚠️ line #{line}: #{message}"
        else
          "⚠️ #{message}"
        end
      end

      private

      def annotation_message
        (line > 1) ? "line #{line}: #{message}" : message
      end

      def annotation_properties
        {file: file_path, line: line, endLine: end_line, col: column, endColumn: end_column}
      end
    end
  end
end
