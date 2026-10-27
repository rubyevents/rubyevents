# frozen_string_literal: true

module Static
  module Validators
    # Every series, event and talk id of the baseline (the merge base with main) still exists or is kept as a former id, so the
    # next seed moves production's records to the new ids instead of leaving them behind. Unlike the per-file
    # validators, this also covers files that no longer exist, like a meetup group's videos.yml after its meetups
    # became events of their own.
    #
    class BaselineIds
      include GitBaseline

      TALK_ID_LINE = '^[[:space:]]*-[[:space:]]+id: "'

      def self.errors
        return [] unless baseline_ref

        series_errors + event_errors + talk_errors
      end

      def self.series_errors
        known = Static::EventSeries.all.flat_map { |series| [series.slug, *series.old_ids] }.to_set

        baseline_series_paths.filter_map do |path|
          id = File.basename(File.dirname(path))
          next if known.include?(id)

          Error.new(
            %(series "#{id}" of #{baseline_ref.first(9)} is gone. Keep it in the renamed series' `old_ids`.),
            file_path: path
          )
        end
      end

      def self.baseline_series_paths
        output, success = git("ls-tree", "-r", "--name-only", baseline_ref, "--", "data")
        return [] unless success

        output.split("\n").grep(%r{\Adata/(?:[^/]+/)+series\.yml\z})
      end

      def self.event_errors
        known = Static::Event.all.flat_map { |event| [event.slug, *event.old_ids] }.to_set
        known.merge(Static::EventSeries.all.flat_map(&:old_event_ids))

        baseline_event_directories.flat_map do |id, directories|
          next [] if known.include?(id)

          directories.map do |directory|
            Error.new(
              %(event "#{id}" of #{baseline_ref.first(9)} is gone. Keep it in the new event's `old_ids`, or in the series' `old_event_ids` when the series took it over.),
              file_path: File.join(directory, "event.yml")
            )
          end
        end
      end

      def self.talk_errors
        known = (Static::Talk.ids + Static::Talk.old_ids + Static::Talk.removed_ids).to_set
        known.merge(Static::Event.all.flat_map(&:old_talk_ids))
        known.merge(Static::EventSeries.all.flat_map(&:removed_talk_ids))

        baseline_talks.filter_map do |id, path, line|
          next if known.include?(id)

          Error.new(
            %(talk "#{id}" of #{baseline_ref.first(9)} is gone. Keep it as the talk's `old_id`, in the meetup's `old_talk_ids` when the talk became the meetup, or in `removed_talk_ids` when it was removed on purpose.),
            file_path: path,
            line: line
          )
        end
      end

      def self.baseline_talks
        output, success = git("grep", "-n", "-E", TALK_ID_LINE, baseline_ref, "--", "*videos.yml")
        return [] unless success

        output.force_encoding("UTF-8").lines.filter_map do |entry|
          _ref, path, line, content = entry.split(":", 4)
          id = content.to_s[/id: "([^"]+)"/, 1]

          [id, path, line.to_i] if id
        end
      end
    end
  end
end
