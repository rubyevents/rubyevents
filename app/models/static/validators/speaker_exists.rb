# frozen_string_literal: true

module Static
  module Validators
    class SpeakerExists
      PATTERNS = ["**/videos.yml"].freeze

      def initialize(file_path:)
        @file_path = file_path.to_s.sub("#{Rails.root}/", "")
      end

      def applicable?
        return false unless File.exist?(@file_path)

        PATTERNS.any? do |pattern|
          File.fnmatch?(pattern, @file_path, File::FNM_PATHNAME)
        end
      end

      def errors
        return [] unless applicable?

        self.class.errors.select { |e| e.file_path == @file_path }
      end

      def self.errors
        @errors ||= Static::SpeakersFile.new.missing_speaker_references.map do |scalar|
          Static::Validators::Error.new(
            %(Speaker "#{scalar.value}" not found in data/speakers.yml),
            file_path: scalar.file_path || "",
            line: scalar.line || 1
          )
        end
      end

      def self.reset!
        @errors = nil
      end
    end
  end
end
