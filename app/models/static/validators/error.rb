module Static
  module Validators
    class Error
      attr_reader :error, :file_path, :line

      def initialize(message, file_path:, line:)
        @message = message
        @file_path = file_path
        @line = line
      end

      def to_h
        {
          "message" => @message,
          "file_path" => @file_path,
          "line" => @line
        }
      end

      def as_error
        prefix = (ENV["GITHUB_ACTIONS"] == "true") ? "::error file=#{file_path},line=#{line}::" : "❌"
        "#{prefix} #{@message}"
      end

      def as_warning
        prefix = (ENV["GITHUB_ACTIONS"] == "true") ? "::warning file=#{file_path},line=#{line}::" : "⚠️"
        "#{prefix} #{@message}"
      end
    end
  end
end
