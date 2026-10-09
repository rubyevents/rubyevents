class Avo::Actions::ImportEventCheckInStandalone < Avo::BaseAction
  self.name = "Import Event Check-ins"
  self.standalone = true

  def fields
    field :event_id, as: :select, name: "Event",
      help: "The event these check-ins belong to",
      options: -> { Event.order(start_date: :desc).pluck(:name, :id) }
    field :file, as: :file, name: "CSV File"
  end

  def handle(fields:, **args)
    event = Event.find_by(id: fields[:event_id])

    if event.blank?
      return error "Please select an event for the import."
    end

    file = fields[:file]

    if file.blank?
      return error "Please upload a CSV file."
    end

    result = EventCheckIn.import_from_csv(event: event, csv_content: file.read)

    succeed "Import complete for #{event.name}: #{result[:created]} created, #{result[:skipped]} duplicates skipped, #{result[:errored]} errors."
  end
end
