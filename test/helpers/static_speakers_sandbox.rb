# frozen_string_literal: true

# Appending to a `references :speakers` field auto-creates missing speakers through
# Static::Speaker. Include this in tests that do so, to point it at a throwaway copy
# of data/speakers.yml instead of the real file.
module StaticSpeakersSandbox
  extend ActiveSupport::Concern

  included do
    setup do
      @sandboxed_speakers_file = Tempfile.new(["speakers", ".yml"])
      FileUtils.cp(Rails.root.join(Static::SpeakersFile::SPEAKERS_PATH), @sandboxed_speakers_file.path)

      @original_speakers_path = Static::Speaker.path
      Static::Speaker.path = @sandboxed_speakers_file.path
      Static::Speaker.unload!
    end

    teardown do
      Static::Speaker.path = @original_speakers_path
      Static::Speaker.unload!

      @sandboxed_speakers_file.close
      @sandboxed_speakers_file.unlink
    end
  end
end
