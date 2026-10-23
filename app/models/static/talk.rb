# frozen_string_literal: true

module Static
  class Talk < Yerba::Record::Base
    SEARCH_INDEX_ON_IMPORT_DEFAULT = ENV.fetch("SEARCH_INDEX_ON_IMPORT", "true") == "true"

    self.path = "data/:series_id/:event_id/videos.yml"
    self.flatten = true

    schema do
      string :id, description: "Unique identifier for the video", required: true
      string :old_id, description: "Previous id, kept so production records can be migrated to the new id on the next seed", required: false
      string :title, description: "Title of the talk"
      string :raw_title, description: "Original/raw title from the video source", required: false
      string :original_title, description: "Original title in native language", required: false
      string :description, description: "Description of the talk"
      string :slug, description: "URL-friendly slug", required: false
      string :kind, description: "Type of video (e.g., 'keynote', 'lightning_talk')", required: false, enum: ::Talk::KIND_LABELS.keys
      string :status, description: "Status of the video", required: false

      array :speakers, of: :string, description: "List of speaker names", required: false
      array :talks, of: SubVideoSchema, description: "Sub-talks for panel discussions", required: false

      string :event_name, description: "Name of the event (e.g., 'RailsConf 2024')", required: false
      string :date, description: "Date of the talk (YYYY-MM-DD format)", required: true, pattern: "^\\d{4}-\\d{2}-\\d{2}$"
      string :start_time, description: "Scheduled start time of the talk", required: false, pattern: "^\\d{2}:\\d{2}$"
      string :end_time, description: "Scheduled end time of the talk", required: false, pattern: "^\\d{2}:\\d{2}$"
      string :published_at, description: "Date when the video was published (YYYY-MM-DD format)", required: false, min_length: 1
      string :announced_at, description: "Date when the talk was announced", required: false, min_length: 1
      string :location, description: "Location within the venue", required: false

      string :video_provider, description: "Video hosting provider", enum: (::Talk.video_providers.keys - ["parent"])
      string :video_id, description: "Video ID on the provider platform"

      boolean :external_player, description: "Whether to use external player", required: false
      string :external_player_url, description: "URL for external player", required: false
      string :track, description: "Conference track (e.g., 'Main Stage', 'Workshop')", required: false
      string :language, description: "Language of the talk", enum: Language.english_names, required: false
      string :slides_url, description: "URL to the slides", required: false

      array :alternative_recordings, of: AlternativeRecordingSchema, description: "Alternative video recordings", required: false
      array :additional_resources, of: AdditionalResourceSchema, description: "Additional resources related to the talk", required: false

      string :thumbnail_xs, description: "Extra small thumbnail URL", required: false
      string :thumbnail_sm, description: "Small thumbnail URL", required: false
      string :thumbnail_md, description: "Medium thumbnail URL", required: false
      string :thumbnail_lg, description: "Large thumbnail URL", required: false
      string :thumbnail_xl, description: "Extra large thumbnail URL", required: false
      string :thumbnail_classes, description: "CSS classes for thumbnail", required: false

      given video_provider: "youtube" do
        requires :published_at
        validates :published_at, type: :string, not_value: "TODO", min_length: 1, pattern: "^\\d{4}-\\d{2}-\\d{2}T\\d{2}:\\d{2}:\\d{2}Z$"
        validates :video_id, type: :string, pattern: "^[A-Za-z0-9_-]{11}$"
      end

      given video_provider: "vimeo" do
        validates :video_id, type: :string, pattern: "^\\d+$"
      end

      given video_provider: "mp4" do
        validates :video_id, type: :string, pattern: "^https?://"
      end

      dependent :published_at do
        validates :video_provider, enum: ::Talk::WATCHABLE_PROVIDERS
      end
    end

    belongs_to :event
    has_one :series, through: :event
    has_many :talks, nested: true
    has_many :alternative_recordings, nested: true, class_name: "Static::Talk::AlternativeRecording"

    has_file :thumbnail, "app/assets/images/thumbnails/:event_id/**/:video_id.webp"
    has_files :child_thumbnails, "app/assets/images/thumbnails/:event_id/:id"

    scope :top_level, -> { where.missing(:parent) }
    scope :youtube, -> { where(video_provider: "youtube") }
    scope :youtube_missing_published_at, -> { youtube.where(published_at: [nil, "", "TODO"]) }

    references :speakers

    add_index :id
    add_index :video_id

    def self.find_by_static_id(id)
      find_by(id: id)
    end

    def self.find_by_video_id(video_id)
      find_by(video_id: video_id)
    end

    def self.import_all!(index: SEARCH_INDEX_ON_IMPORT_DEFAULT)
      import!(index: index)
    end

    def self.import!(event: nil, index: SEARCH_INDEX_ON_IMPORT_DEFAULT)
      imported = {}

      all.each do |talk|
        parent_talk = talk.parent && imported[talk.parent]
        next if talk.parent && parent_talk.nil?

        imported[talk] = talk.import!(event: event, parent_talk: parent_talk, index: index)
      end

      imported.values.compact
    end

    def self.pairs
      top_level.map { |talk| [talk, talk.talks.to_a] }
    end

    def self.ids
      all.filter_map(&:id)
    end

    def self.old_ids
      all.filter_map(&:old_id)
    end

    def self.removed_ids
      all.documents.flat_map do |document|
        next [] if document.path.blank?

        params = path_params_for(document.path) || {}
        event = Static::Event.find_by_file_path(Static::Event.path_for({series_id: params[:series_id], id: params[:event_id]}))

        Array(event&.[]("removed_talk_ids"))
      end
    end

    def self.talks_by_id
      all.index_by(&:id).except(nil)
    end

    def old_id
      self["old_id"]
    end

    def raw_title
      self["raw_title"] || title
    end

    def description
      self["description"] || ""
    end

    def start_cue
      self["start_cue"]
    end

    def end_cue
      self["end_cue"]
    end

    def kind
      self["kind"].presence || ::Talk::Kind.from_title(title).to_s
    end

    def thumbnail_cue
      duration_to_formatted_cue(ActiveSupport::Duration.build(thumbnail_cue_in_seconds))
    end

    def duration_fs
      duration_to_formatted_cue(duration)
    end

    def duration_to_formatted_cue(duration)
      Duration.seconds_to_formatted_duration(duration)
    end

    def duration
      ActiveSupport::Duration.build(duration_in_seconds)
    end

    def duration_in_seconds
      end_cue_in_seconds - start_cue_in_seconds
    end

    def start_cue_in_seconds
      convert_cue_to_seconds(start_cue)
    end

    def end_cue_in_seconds
      convert_cue_to_seconds(end_cue)
    end

    def thumbnail_cue_in_seconds
      (self["thumbnail_cue"] && self["thumbnail_cue"] != "TODO") ? convert_cue_to_seconds(self["thumbnail_cue"]) : (start_cue_in_seconds + 5)
    end

    def convert_cue_to_seconds(cue)
      return nil if cue.blank?

      cue.split(":").map(&:to_i).reverse.each_with_index.reduce(0) do |sum, (value, index)|
        sum + value * 60**index
      end
    end

    def meta_talk?
      attributes.key?("talks")
    end

    def import!(event: nil, parent_talk: nil, index: SEARCH_INDEX_ON_IMPORT_DEFAULT)
      if title.blank?
        puts "Ignored video: #{raw_title}"
        return nil
      end

      event ||= self.event&.event_record

      raise "Event not found for video #{id}" unless event

      talk = find_or_initialize_talk
      talk.parent_talk = parent_talk if parent_talk
      talk.update_from_yml_metadata!(event: event)

      Search::Backend.index(talk) if index

      talk
    rescue ActiveRecord::RecordInvalid => e
      puts "Couldn't save: #{title} (#{id}), error: #{e.message}"
      nil
    end

    def find_or_initialize_talk
      talk = ::Talk.find_by(static_id: id)
      talk ||= ::Talk.find_by(static_id: old_id) if old_id.present?
      talk ||= ::Talk.new
      talk.static_id = id
      talk
    end
  end
end
