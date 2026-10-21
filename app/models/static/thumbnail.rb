# frozen_string_literal: true

module Static
  class Thumbnail < Yerba::Record::FileRecord
    REMOTE_THUMBNAIL_PROVIDERS = %w[youtube vimeo].freeze

    self.path = "app/assets/images/thumbnails/**/:video_id.webp"

    validate :not_redundant, on: :lint

    def self.talk_lookup
      Yerba::Record::Validations.cached(self, :talk_lookup) do
        Static::Talk.all.each_with_object({}) do |talk, lookup|
          entry = {talk: talk, event_slug: File.basename(File.dirname(talk.file_path.to_s)), parent_id: talk.parent&.id}

          [talk.id, talk.video_id].compact.each { |key| lookup[key] ||= entry }
        end
      end
    end

    def directory
      File.dirname(file_path.split("thumbnails/").last)
    end

    private

    def not_redundant
      entry = self.class.talk_lookup[video_id]
      return redundant("no talk with video_id '#{video_id}' exists, this file can be deleted") unless entry

      expected_directory = File.join(*[entry[:event_slug], entry[:parent_id]].compact)

      if directory != expected_directory
        return redundant("talk '#{video_id}' belongs to '#{expected_directory}', move this file to thumbnails/#{expected_directory}/#{video_id}.webp")
      end

      talk = entry[:talk]
      return if talk.start_cue.present? && talk.start_cue != "TODO"
      return unless talk["video_provider"].in?(REMOTE_THUMBNAIL_PROVIDERS)

      redundant("talk '#{video_id}' has no start_cue and its #{talk["video_provider"]} thumbnail is available remotely, this file can be deleted")
    end

    def redundant(message)
      errors.add(:base, "Redundant thumbnail: #{message}")
    end
  end
end
