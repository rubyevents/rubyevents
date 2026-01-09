class Avo::Actions::GeocodeEvent < Avo::BaseAction
  self.name = "Geocode event"

  def handle(query:, fields:, current_user:, resource:, records:, **args)
    events = records.presence || query.to_a
    perform_in_background = events.size >= 10
    processed = 0
    skipped = 0

    events.each do |event|
      if event.location.blank?
        skipped += 1
        next
      end

      if perform_in_background
        GeocodeEventJob.perform_later(event)
      else
        GeocodeEventJob.perform_now(event)
      end

      processed += 1
    end

    message = "Geocoding #{perform_in_background ? "enqueued" : "completed"} for #{processed} event(s)"
    message += " (#{skipped} skipped without location or venue)" if skipped > 0
    succeed message
  end
end
