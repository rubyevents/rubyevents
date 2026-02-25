class Avo::Actions::GeocodeRecord < Avo::BaseAction
  self.name = "Geocode location"

  def handle(query:, fields:, current_user:, resource:, records:, **args)
    items = records.presence || query.to_a
    perform_in_background = items.size >= 10
    processed = 0
    skipped = 0

    model_name = items.first&.model_name&.human&.downcase || "record"

    items.each do |record|
      unless record.geocodeable?
        skipped += 1
        next
      end

      if perform_in_background
        GeocodeRecordJob.perform_later(record)
      else
        GeocodeRecordJob.perform_now(record)
      end

      processed += 1
    end

    message = "Geocoding #{perform_in_background ? "enqueued" : "completed"} for #{processed} #{model_name.pluralize(processed)}"
    message += " (#{skipped} skipped without location)" if skipped > 0
    succeed message
  end
end
