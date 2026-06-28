namespace :backfill do
  require "gum"

  desc "Backfill EventParticipation records for existing speakers"
  task speaker_participation: :environment do
    puts Gum.style("Backfilling speaker participation records", border: "rounded", padding: "0 2", border_foreground: "5")
    puts

    role = Arel.sql("CASE WHEN talks.kind = 'keynote' THEN 'keynote_speaker' ELSE 'speaker' END")
    tuples = UserTalk.kept.joins(talk: :event)
      .pluck("user_talks.user_id", "events.id", role)
      .uniq

    puts "Found #{tuples.size} distinct speaker participations to ensure"
    puts

    now = Time.current
    rows = tuples.map do |user_id, event_id, attended_as|
      {user_id: user_id, event_id: event_id, attended_as: attended_as, created_at: now, updated_at: now}
    end

    created_count = 0

    if rows.any?
      result = EventParticipation.insert_all(rows, unique_by: [:user_id, :event_id, :attended_as])
      created_count = result.length

      EventParticipation
        .attended_as_visitor
        .where(
          "EXISTS (SELECT 1 FROM event_participations speakers " \
          "WHERE speakers.user_id = event_participations.user_id " \
          "AND speakers.event_id = event_participations.event_id " \
          "AND speakers.attended_as IN ('speaker', 'keynote_speaker'))"
        )
        .delete_all
    end

    puts Gum.style("Backfill completed!", border: "rounded", padding: "0 2", foreground: "2", border_foreground: "2")
    puts
    puts "Distinct participations: #{rows.size}"
    puts Gum.style("✓ New participations created: #{created_count}", foreground: "2")
  end
end
