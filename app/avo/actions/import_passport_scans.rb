class Avo::Actions::ImportPassportScans < Avo::BaseAction
  self.name = "Import Passport Scans"
  self.standalone = true

  def fields
    field :event, as: :select, options: Event.all.map { |event| [event.name, event.id] }, include_blank: true, required: true
    field :file, as: :file, accept: "text/csv"
  end

  def handle(query:, fields:, current_user:, resource:, **args)
    event_id = fields[:event]
    begin
      event = Event.find(event_id)
    rescue ActiveRecord::RecordNotFound
      error "Event not found: #{event_id}"
      return
    end
    file = fields[:file]

    if file.present?
      rows = []
      CSV.parse(file.read, headers: true) do |row|
        rows << row.to_h.stringify_keys
      end

      # Cache connected accounts
      connected_accounts = ConnectedAccount.where(uid: rows.map { |row| row["connect_id"] }).index_by(&:uid)

      rows.each do |row|
        if row["connect_id"].present?
          connected_account = connected_accounts[row["connect_id"]]
          next if connected_account.blank?

          user = connected_account.user
          next if user.blank?

          # Create or update attendance
          attendance = EventParticipation.find_or_create_by!(user: user, event: event, attended_as: "visitor")
          attendance.update!(verified_at: row["created_at"], attendance_details: {scan_type: row["scan_type"], connect_id: row["connect_id"]})
        end
      end
    end
  end
end
