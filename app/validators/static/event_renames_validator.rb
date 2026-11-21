# frozen_string_literal: true

module Static
  # An event that is new on this branch, while an event of the same series from main is gone, was most likely renamed.
  # Production finds the event it already has by the previous id in `old_ids`.
  #
  class EventRenamesValidator < ActiveModel::Validator
    include GitBaseline

    def validate(event)
      disappeared = disappeared_ids(event)
      return if disappeared.empty?

      previous = disappeared.map { %("#{it}") }.join(", ")

      event.errors.add(:base, %(event "#{event["id"]}" is new, while #{previous} from main is gone from this series. If "#{event["id"]}" was renamed, keep the previous id in `old_ids` so production moves the event and its old URLs redirect. Run `bin/rails validate:fix` to add it.), at: "id")
    end

    def fix(event)
      disappeared = disappeared_ids(event)
      return 0 unless disappeared.one? && new_events_in_series(event).one?

      event["old_ids"] = event.old_ids + disappeared

      1
    end

    private

    def disappeared_ids(event)
      return [] unless self.class.baseline_ref && changed_since_baseline?(event) && new_event?(event)

      series = File.basename(series_directory(event))
      baseline_ids = self.class.baseline_event_directories.select { |_id, directories| directories.any? { File.basename(File.dirname(it)) == series } }.keys

      baseline_ids - known_ids
    end

    def changed_since_baseline?(event)
      self.class.changed_paths.nil? || self.class.changed_paths.include?(event.project_file_path)
    end

    def new_event?(event)
      event.old_ids.empty? && self.class.baseline_file(event.project_file_path).nil?
    end

    def known_ids
      Yerba::Record::Validations.cached(self.class, :known_ids) do
        event_ids = Static::Event.all.flat_map { [it["id"], *it.old_ids] }
        merged_ids = Static::EventSeries.all.flat_map(&:old_event_ids)

        (event_ids + merged_ids).compact
      end
    end

    def new_events_in_series(event)
      Dir[File.join(series_directory(event), "*", "event.yml")].select do |path|
        sibling = Static::Event.in_file(path).first
        sibling && sibling.old_ids.empty? && self.class.baseline_file(sibling.project_file_path).nil?
      end
    end

    def series_directory(event)
      File.dirname(File.expand_path(event.file_path.to_s), 2)
    end
  end
end
