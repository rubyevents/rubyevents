# frozen_string_literal: true

module SpeakersFileCheck
  extend ActiveSupport::Concern

  def initialize(speakers_file_path: nil)
    @speakers_file_path = speakers_file_path

    super()
  end

  private

  def speakers
    @speakers ||= Static::Speaker.in_file(@speakers_file_path || Static::Speaker.file_path)
  end

  def check_speakers_file(result)
    missing = speakers.missing_speakers
    orphaned = speakers.orphaned_speakers

    warnings = []
    warnings << "#{missing.length} missing speaker(s): #{missing.first(5).join(", ")}" if missing.any?
    warnings << "#{orphaned.length} orphaned speaker(s): #{orphaned.first(5).join(", ")}" if orphaned.any?

    result[:warnings] = warnings if warnings.any?
    result
  end
end
