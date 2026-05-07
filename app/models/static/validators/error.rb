module Static
  module Validators
    class Error
      attr_reader :error, :file_path, :line, :end_line

      def initialize(message, file_path:, line:, end_line:)
        @message = message
        @file_path = file_path.sub("#{Rails.root}/", "")
        @line = line
        @end_line = end_line || line
      end

      def to_h
        {
          "message" => @message,
          "file_path" => @file_path,
          "line" => @line,
          "end_line" => @end_line
        }
      end

      def as_error
        prefix = if ENV["GITHUB_ACTIONS"] == "true"
          "::error file=#{file_path},line=#{line},endLine=#{end_line}::"
        elsif line > 1
          "❌ line #{line}:"
        else
          "❌"
        end
        "#{prefix} #{@message}"
      end

      def as_warning
        prefix = if ENV["GITHUB_ACTIONS"] == "true"
          "::warning file=#{file_path},line=#{line},endLine=#{end_line}::"
        elsif line > 1
          "⚠️ line #{line}:"
        else
          "⚠️"
        end
        "#{prefix} #{@message}"
      end
    end
  end
end
