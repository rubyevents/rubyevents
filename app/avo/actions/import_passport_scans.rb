class Avo::Actions::ImportPassportScans < Avo::BaseAction
  self.name = "Import Passport Scans"
  self.standalone = true
  # self.visible = -> do
  #   true
  # end

  def fields
    field :file, as: :file, accept: "text/csv"
  end

  def handle(query:, fields:, current_user:, resource:, **args)
    puts ["field!->", fields[:file]].inspect
    file = fields[:file]

    if file.present?

      rows = []
      # puts ["file->", file, file.read].inspect
      CSV.parse(file.read, headers: true) do |row|
        slug = case row["event"]
        when "rails_world_2025"
          "rails-world-2025"
        when "friendly_25"
          "friendly-rb-2025"
        when "euruko_25"
          "euruko-2025"
          # when "prug"
          #   "prug-2025"
        end

        new_row = row.to_h.merge({
          slug:
        }).stringify_keys

        rows << new_row
      end

      # Cache events
      row_events = rows.map { |row| row["slug"] }.uniq
      events = Event.where(slug: row_events).index_by(&:slug)

      # Cache connected accounts
      connected_accounts = ConnectedAccount.where(uid: rows.map { |row| row["connect_id"] }).index_by(&:uid)

      rows.each do |row|
        event = events[row["slug"]]

        if event.blank?
          error "Event name not found: #{row["event"]}"
          next
        end

        if row["connect_id"].present?
          # search for aconnected account
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
