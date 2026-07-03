module YouTube
  class VideoMetadataBalticRuby2024
    SPEAKERS_SECTION_SEPARATOR = " - "
    SEPARATOR_IN_BETWEEN_SPEAKERS = / & |, | and /

    def initialize(metadata:, event_name:, options: {})
      @metadata = metadata
      @event_name = event_name
    end

    def cleaned
      OpenStruct.new(
        {
          title: title,
          raw_title: raw_title,
          speakers: speakers,
          event_name: @event_name,
          published_at: @metadata.published_at,
          description: description_without_speaker,
          video_provider: :youtube,
          video_id: @metadata.video_id
        }
      )
    end

    def keynote?
      raw_description.match(/keynote/i)
    end

    private

    def speakers
      speaker_line = raw_description.split("\n").find { |line| line.downcase.include?("speaker") }

      _, names = speaker_line.split(":")

      return [] if speaker_line.blank?

      raw_speakers = names.split(SEPARATOR_IN_BETWEEN_SPEAKERS)

      raw_speakers.map { |speaker|
        remove_leading_and_trailing_separators_from(speaker).split(" ").map { |name| name.capitalize }.join(" ")
      }
    end

    def raw_title
      @metadata.title
    end

    def title_without_event_name
      remove_leading_and_trailing_separators_from(raw_title.gsub(@event_name, "").gsub(/\s+/, " "))
    end

    def remove_leading_and_trailing_separators_from(title)
      return title if title.blank?

      title.gsub(/^[-:]?/, "").strip.then do |title|
        title.gsub(/[-:,.]$/, "").strip
      end
    end

    def title
      t = remove_leading_and_trailing_separators_from(title_without_event_name).to_s.delete('"')

      keynote? ? "Keynote: #{t}" : t
    end

    def raw_description
      @metadata.description
    end

    def description_without_speaker
      @metadata.description.split("\n").reject { |line| line.downcase.include?("speaker") }.join("\n").strip
    end
  end
end
