# frozen_string_literal: true

module Static
  # Talks that share one recording, like a meetup's full video cut into its talks or a conference's talks nested under
  # a `parent` recording, each need their own part of it. A talk that shares a video with other top-level talks needs a
  # `start_cue` and an `end_cue` ("TODO" until they are known), and the cues of one recording follow the order of the
  # talks in the file without overlapping. Talks of one recording in different files can't overlap either.
  #
  # The recordings are worked out for all talks at once, as [talk, attribute, message, at:] errors.
  #
  class RecordingCuesValidator < ActiveModel::Validator
    def validate(talk)
      errors = Yerba::Record::Validations.cached(self.class, :errors) { self.class.errors_in(Static::Talk.all.to_a) }

      errors.fetch(self.class.key(talk), []).each do |attribute, message, at|
        talk.errors.add(attribute, message, **{at: at}.compact)
      end
    end

    # {[file_path, selector] => [[attribute, message, at]]}
    def self.errors_in(talks)
      errors = recordings(talks).flat_map { |shared, recording| missing_cue_errors(shared, recording) + order_errors(recording) } +
        shared_recordings(talks).flat_map { |recording| overlap_errors_across_files(recording) }

      errors.group_by { |talk, *| key(talk) }.transform_values { |group| group.map { |_, *error| error } }
    end

    def self.key(talk)
      [File.expand_path(talk.file_path.to_s), talk.selector]
    end

    def self.shared_recordings(talks)
      talks
        .select { |talk| talk.parent.nil? && ::Talk::WATCHABLE_PROVIDERS.include?(talk["video_provider"]) }
        .group_by { |talk| [talk["video_provider"], talk["video_id"]] }
        .values.select(&:many?)
    end

    def self.recordings(talks)
      shared = shared_recordings(talks)
        .flat_map { |recording| recording.group_by(&:file_path).values.map { |talks_in_file| [recording, talks_in_file] } }

      nested = talks
        .select { |talk| talk.parent && talk["video_provider"] == "parent" }
        .group_by(&:parent).values.map { |recording| [nil, recording] }

      shared + nested
    end

    def self.missing_cue_errors(shared, recording)
      return [] unless shared

      recording.filter_map do |talk|
        missing = %w[start_cue end_cue].select { |key| talk[key].blank? }
        next if missing.empty?

        others = shared.size - 1

        [talk, :base, %(#{missing.to_sentence} #{missing.one? ? "is" : "are"} missing. This talk shares its #{talk["video_provider"]} video "#{talk["video_id"]}" with #{others} other #{"talk".pluralize(others)}, so it needs its own cues ("TODO" until they are known).), "id"]
      end
    end

    def self.cued(recording)
      recording.filter_map do |talk|
        start_seconds = Static::ShortTalkKindValidator.cue_to_seconds(talk["start_cue"])
        end_seconds = Static::ShortTalkKindValidator.cue_to_seconds(talk["end_cue"])

        [talk, start_seconds, end_seconds] if start_seconds && end_seconds
      end
    end

    def self.order_errors(recording)
      cued = cued(recording)

      inverted = cued.filter_map do |talk, start_seconds, end_seconds|
        next if end_seconds > start_seconds

        [talk, :end_cue, %("#{talk["end_cue"]}" isn't after start_cue "#{talk["start_cue"]}".), nil]
      end

      sequence = cued.each_cons(2).filter_map do |(previous, previous_start, previous_end), (talk, start_seconds, _)|
        if start_seconds < previous_start
          [talk, :start_cue, %("#{talk["start_cue"]}" is before "#{previous["id"]}", which starts at "#{previous["start_cue"]}". List the talks in the order of the recording.), nil]
        elsif start_seconds < previous_end
          [talk, :start_cue, %("#{talk["start_cue"]}" overlaps "#{previous["id"]}", which ends at "#{previous["end_cue"]}".), nil]
        end
      end

      inverted + sequence
    end

    # Files have no order between them, so their talks of one recording only need to stay out of each other's cues
    def self.overlap_errors_across_files(recording)
      cued(recording)
        .select { |_, start_seconds, end_seconds| end_seconds > start_seconds }
        .combination(2)
        .flat_map do |(talk, start_seconds, end_seconds), (other, other_start, other_end)|
          next [] if talk.file_path == other.file_path || start_seconds >= other_end || other_start >= end_seconds

          [overlap_error(talk, other), overlap_error(other, talk)]
        end
    end

    def self.overlap_error(talk, other)
      [talk, :base, %(cues "#{talk["start_cue"]}" to "#{talk["end_cue"]}" overlap "#{other["id"]}" in #{other.project_file_path}, which uses the same #{other["video_provider"]} video "#{other["video_id"]}" from "#{other["start_cue"]}" to "#{other["end_cue"]}".), "start_cue"]
    end
  end
end
