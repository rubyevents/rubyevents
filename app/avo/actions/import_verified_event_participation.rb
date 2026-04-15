class Avo::Actions::ImportVerifiedEventParticipation < Avo::BaseAction
  self.name = "Import Verified Event Participation"

  def fields
    field :file, as: :file, name: "CSV File"
  end

  def handle(query:, fields:, current_user:, resource:, **args)
    if query.count != 1
      return error "Please select exactly one event for the import."
    end

    event = query.first
    file = fields[:file]

    if file.blank?
      return error "Please upload a CSV file."
    end

    csv_content = file.read
    result = VerifiedEventParticipation.import_from_csv(event: event, csv_content: csv_content)

    succeed "Import complete for #{event.name}: #{result[:created]} created, #{result[:skipped]} duplicates skipped, #{result[:errored]} errors."
  end
end
