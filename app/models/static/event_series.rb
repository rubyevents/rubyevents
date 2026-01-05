module Static
  class EventSeries < FrozenRecord::Base
    self.backend = Backends::MultiFileBackend.new("*/series.yml")
    self.base_path = Rails.root.join("data")

    SEARCH_INDEX_ON_IMPORT_DEFAULT = ENV.fetch("SEARCH_INDEX_ON_IMPORT", "true") == "true"

    class << self
      def find_by_slug(slug)
        @slug_index ||= all.index_by(&:slug)
        @slug_index[slug]
      end

      def import_all!(index: SEARCH_INDEX_ON_IMPORT_DEFAULT)
        all.each { |series| series.import!(index: index) }
      end

      def import_all_series!(index: SEARCH_INDEX_ON_IMPORT_DEFAULT)
        all.each { |series| series.import_series!(index: index) }
      end

      def create(
        name:,
        slug: nil,
        description: nil,
        kind: nil,
        frequency: nil,
        ended: nil,
        default_country_code: nil,
        language: nil,
        website: nil,
        original_website: nil,
        twitter: nil,
        mastodon: nil,
        bsky: nil,
        github: nil,
        linkedin: nil,
        meetup: nil,
        luma: nil,
        guild: nil,
        vimeo: nil,
        youtube_channel_id: nil,
        youtube_channel_name: nil,
        playlist_matcher: nil,
        aliases: nil
      )
        slug ||= name.parameterize

        series_dir = base_path.join(slug)
        series_file = series_dir.join("series.yml")

        if series_file.exist?
          raise ArgumentError, "Event series '#{slug}' already exists at #{series_file}"
        end

        data = {"name" => name}

        data["description"] = description if description.present?
        data["kind"] = kind if kind.present?
        data["frequency"] = frequency if frequency.present?
        data["ended"] = ended unless ended.nil?
        data["default_country_code"] = default_country_code if default_country_code.present?
        data["language"] = language if language.present?
        data["website"] = website if website.present?
        data["original_website"] = original_website if original_website.present?
        data["twitter"] = twitter if twitter.present?
        data["mastodon"] = mastodon if mastodon.present?
        data["bsky"] = bsky if bsky.present?
        data["github"] = github if github.present?
        data["linkedin"] = linkedin if linkedin.present?
        data["meetup"] = meetup if meetup.present?
        data["luma"] = luma if luma.present?
        data["guild"] = guild if guild.present?
        data["vimeo"] = vimeo if vimeo.present?
        data["youtube_channel_id"] = youtube_channel_id if youtube_channel_id.present?
        data["youtube_channel_name"] = youtube_channel_name if youtube_channel_name.present?
        data["playlist_matcher"] = playlist_matcher if playlist_matcher.present?
        data["aliases"] = Array(aliases) if aliases.present?

        schema = JSON.parse(SeriesSchema.new.to_json_schema[:schema].to_json)
        schemer = JSONSchemer.schema(schema)
        errors = schemer.validate(data).to_a

        if errors.any?
          error_messages = errors.map { |e| "#{e["error"]} at #{e["data_pointer"]}" }
          raise ArgumentError, "Validation failed: #{error_messages.join(", ")}"
        end

        FileUtils.mkdir_p(series_dir)
        File.write(series_file, data.to_yaml)

        @slug_index = nil
        unload!

        find_by_slug(slug)
      end
    end

    def slug
      @slug ||= File.basename(File.dirname(__file_path))
    end

    def event_series_record
      @event_series_record ||= ::EventSeries.find_by(slug: slug) || import_series!
    end

    def import_series!(index: SEARCH_INDEX_ON_IMPORT_DEFAULT)
      event_series = ::EventSeries.find_or_initialize_by(slug: slug)

      event_series.update!(
        name: name,
        website: website || "",
        twitter: twitter || "",
        youtube_channel_name: youtube_channel_name,
        kind: kind,
        frequency: frequency,
        youtube_channel_id: youtube_channel_id,
        slug: slug,
        language: language || ""
      )

      event_series.sync_aliases_from_list(aliases) if aliases.present?

      Search::Backend.index(event_series) if index

      event_series
    end

    def import!(index: SEARCH_INDEX_ON_IMPORT_DEFAULT)
      import_series!(index: index)
      events.each { |event| event.import!(index: index) }
      event_series_record
    end

    def events
      @events ||= Static::Event.all.select { |event| event.series_slug == slug }
    end
  end
end
