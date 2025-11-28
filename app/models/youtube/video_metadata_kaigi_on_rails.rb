module YouTube
  class VideoMetadataKaigiOnRails < VideoMetadata
    # TODO: `SPEAKERS_SECTION_SEPARATOR` should be a method so that chldren classes can override it
    def title
      if keynote? || lighting?
        # when it is a keynote or lighting, usually we want to keep the full title without the event name
        remove_leading_and_trailing_separators_from(title_without_event_name)
      else
        title = title_parts[0..-2].join(SPEAKERS_SECTION_SEPARATOR).gsub(/^\s*-/, "").strip
        remove_leading_and_trailing_separators_from(title)
      end
    end

    def speakers
      title_parts.last.split(SEPARATOR_IN_BETWEEN_SPEAKERS).map(&:strip)
    end

    private

    def title_parts
      title_without_event_name.split(" / ")
    end
  end
end
