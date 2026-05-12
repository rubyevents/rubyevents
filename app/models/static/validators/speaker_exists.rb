# frozen_string_literal: true

module Static
  module Validators
    class SpeakerExists
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
