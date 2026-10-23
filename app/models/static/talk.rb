# frozen_string_literal: true

module Static
  class Talk < Yerba::Record::Base
    SEARCH_INDEX_ON_IMPORT_DEFAULT = ENV.fetch("SEARCH_INDEX_ON_IMPORT", "true") == "true"

    self.path = "data/:series_id/:event_id/videos.yml"
    self.flatten = true

    schema VideoSchema

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

    PROVIDERS_WITHOUT_PUBLISHED_AT = (::Talk::UNPUBLISHED_PROVIDERS + ["children", "parent"]).freeze

    validates :id, uniqueness: {also: :old_id}, on: :lint
    validates :old_id, uniqueness: {also: :id}, on: :lint
    validates :speakers, "static/speaker_exists": true, on: :lint
    validates :thumbnail, file: {presence: true, message: ->(talk, _) { %(missing thumbnail for talk "#{talk.video_id}" at #{talk.expected_thumbnail_path}. Run `bin/rails extract_thumbnails` to generate it.) }}, if: :extracted_thumbnail?, on: :lint
    validates :track, inclusion: {in: ->(talk) { talk.event.schedule.track_names }, message: ->(talk, data) { %("#{data[:value]}" is not defined in the tracks of schedule.yml (defined: #{talk.event.schedule.track_names.map { |name| %("#{name}") }.join(", ").presence || "none"}). Fix the track name or add it to the tracks in schedule.yml.) }}, allow_blank: true, if: -> { event&.schedule }, on: :lint
    validates :kind, "static/inferred_kind": true
    validates :published_at, absence: {message: ->(talk, data) { %((#{data[:value]}) must not be set when video_provider is "#{talk["video_provider"]}") }}, if: -> { self["video_provider"].in?(PROVIDERS_WITHOUT_PUBLISHED_AT) }

    validates_with Static::TalkDatesValidator, Static::TalkIdValidator, Static::TalkLanguageValidator, on: :lint
    validates_with Static::SpeakersOrTalksValidator, Static::ShortTalkKindValidator

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

    def extracted_thumbnail?
      parent.present? && parent.id.present? && video_id.present? &&
        Array(self["speakers"]).any? { |name| name.to_s.strip.present? } &&
        start_cue.present? && start_cue != "TODO"
    end

    def expected_thumbnail_path
      "app/assets/images/thumbnails/#{event_id}/#{parent&.id}/#{video_id}.webp"
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
