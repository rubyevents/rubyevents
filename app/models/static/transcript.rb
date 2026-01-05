module Static
  class Transcript < FrozenRecord::Base
    self.backend = Backends::MultiFileBackend.new("**/**/transcripts.yml")
    self.base_path = Rails.root.join("data")

    SEARCH_INDEX_ON_IMPORT_DEFAULT = ENV.fetch("SEARCH_INDEX_ON_IMPORT", "true") == "true"

    class << self
      def find_by_video_id(video_id)
        @video_id_index ||= all.index_by { |t| t["video_id"] }
        @video_id_index[video_id]
      end

      def import_all!(index: SEARCH_INDEX_ON_IMPORT_DEFAULT)
        all.each { |transcript| transcript.import!(index: index) }
      end
    end

    def video_id
      self["video_id"]
    end

    def cues
      self["cues"] || []
    end

    def to_transcript
      transcript = ::Transcript.new
      cues.each do |cue_data|
        transcript.add_cue(
          Cue.new(
            start_time: cue_data["start_time"],
            end_time: cue_data["end_time"],
            text: cue_data["text"]
          )
        )
      end
      transcript
    end

    def import!(index: SEARCH_INDEX_ON_IMPORT_DEFAULT)
      talk = ::Talk.find_by(video_id: video_id)
      return unless talk

      transcript_record = talk.talk_transcript || ::Talk::Transcript.new(talk: talk)
      transcript_record.update!(raw_transcript: to_transcript)

      ::SearchBackend.index(talk) if index

      transcript_record
    end

    def event_slug
      return nil unless __file_path

      __file_path.split("/")[-2]
    end

    def series_slug
      return nil unless __file_path

      __file_path.split("/")[-3]
    end

    def __file_path
      attributes["__file_path"]
    end
  end
end
