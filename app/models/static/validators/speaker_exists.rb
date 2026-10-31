# frozen_string_literal: true

module Static
  module Validators
    class SpeakerExists < ReferenceExists
      PATTERNS = ["**/videos.yml", "**/involvements.yml"].freeze

      def self.model
        Static::Speaker
      end

      def self.missing_references(speakers)
        speakers.missing_speaker_references
      end

      def self.add_missing
        Static::Speaker.add_missing_speakers
      end

      def self.message(reference)
        %(Speaker "#{reference.value}" not found in data/speakers.yml)
      end
    end
  end
end
