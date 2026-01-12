# require "active_support/core_ext/hash/keys"

# This class is used to extract the metadata from a youtube video
# it will try to:
# - extract the speakers from the title
# - remove the event_name from the title to make less redondant
# - remove leading separators from the title
module YouTube
  class VideoMetadata
    SPEAKERS_SECTION_SEPARATOR = " by "
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
          date: "TODO",
          event_name: @event_name,
          published_at: @metadata.published_at,
          announced_at: "TODO",
          description: description,
          video_provider: "youtube",
          video_id: @metadata.video_id
        }
      )
    end

    def keynote?
      title_without_event_name.match(/keynote/i)
    end

    def lighting?
      title_without_event_name.match(/lightning talks/i)
    end

    private

    def extract_info_from_title
      title_parts = title_without_event_name.split(SPEAKERS_SECTION_SEPARATOR)
      speakers = title_parts.last.split(SEPARATOR_IN_BETWEEN_SPEAKERS).map(&:strip)
      title = title_parts[0..-2].join(SPEAKERS_SECTION_SEPARATOR).gsub(/^\s*-/, "").strip

      {
        title: keynote? ? remove_leading_and_trailing_separators_from(title_without_event_name) : remove_leading_and_trailing_separators_from(title),
        speakers: speakers
      }
    end

    def speakers
      return [] if lighting?

      title_parts = title_without_event_name.split(SPEAKERS_SECTION_SEPARATOR)
      title_parts.last.split(SEPARATOR_IN_BETWEEN_SPEAKERS).map(&:strip)
    end

    def raw_title
      @metadata.title
    end

    def title_without_event_name
      # RubyConf AU 2013: From Stubbies to Longnecks by Geoffrey Giesemann
      # will return "From Stubbies to Longnecks by Geoffrey Giesemann"
      remove_leading_and_trailing_separators_from(raw_title.gsub(@event_name, "").gsub(/\s+/, " "))
    end

    ## remove : - and other separators from the title
    def remove_leading_and_trailing_separators_from(title)
      title.gsub(/^[-:]?/, "").strip.then do |title|
        title.gsub(/[-:,]$/, "").strip
      end
    end

    def title
      if keynote? || lighting?
        # when it is a keynote or lighting, usually we want to keep the full title without the event name
        remove_leading_and_trailing_separators_from(title_without_event_name)
      else
        title_parts = title_without_event_name.split(SPEAKERS_SECTION_SEPARATOR)
        title = title_parts[0..-2].join(SPEAKERS_SECTION_SEPARATOR).gsub(/^\s*-/, "").strip
        remove_leading_and_trailing_separators_from(title)
      end
    end

    def description
      @metadata.description
    end
  end
end
