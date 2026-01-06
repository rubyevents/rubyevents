class Avo::Actions::GeocodeUser < Avo::BaseAction
  self.name = "Geocode location"

  def handle(query:, fields:, current_user:, resource:, records:, **args)
    users = records.presence || query.to_a
    perform_in_background = users.size >= 10
    processed = 0
    skipped = 0

    users.each do |user|
      if user.location.blank?
        skipped += 1
        next
      end

      if perform_in_background
        GeocodeUserJob.perform_later(user)
      else
        GeocodeUserJob.perform_now(user)
      end

      processed += 1
    end

    message = "Geocoding #{perform_in_background ? "enqueued" : "completed"} for #{processed} user(s)"
    message += " (#{skipped} skipped without location)" if skipped > 0
    succeed message
  end
end
