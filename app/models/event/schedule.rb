class Event::Schedule < ActiveRecord::AssociatedObject
  include YAMLFile

  yaml_file "schedule.yml"

  def days
    file.fetch("days", [])
  end

  def tracks
    file.fetch("tracks", [])
  end

  def talk_offsets
    days.map { |day|
      grid = day.fetch("grid", [])

      grid.sum { |item| item.fetch("items", []).any? ? 0 : item["slots"] }
    }
  end

  def sessions
    zone = event.static_metadata.time_zone
    zone = ActiveSupport::TimeZone["UTC"] unless zone.is_a?(ActiveSupport::TimeZone)
    all_talks = event.talks_in_running_order(child_talks: false).includes(:speakers).to_a
    offsets = talk_offsets
    track_lookup = tracks.index_by { |track| track["name"] }

    result = []

    days.each_with_index do |day, day_index|
      date = day["date"]
      day_talks = all_talks[offsets.first(day_index).sum, offsets[day_index].to_i] || []
      running = 0

      day.fetch("grid", []).each do |grid|
        start_at = parse_local_time(zone, date, grid["start_time"])
        end_at = parse_local_time(zone, date, grid["end_time"])
        next unless start_at && end_at

        items = grid.fetch("items", [])
        slots = (grid["slots"] || items.size).to_i

        talks =
          if items.any?
            items.map { |item| item.is_a?(String) ? {title: item} : {title: item["title"].to_s} }
              .reject { |talk| talk[:title].blank? }
          else
            slot_talks = day_talks[running, slots] || []
            running += slots

            slot_talks.map { |talk| talk_entry(talk, track_lookup) }
          end

        result << {start_at: start_at, end_at: end_at, talks: talks}
      end
    end

    result.sort_by { |session| session[:start_at] }
  end

  def current_session(now = Time.current)
    sessions.find { |session| session[:start_at] <= now && now < session[:end_at] }
  end

  def next_session(now = Time.current)
    sessions.select { |session| session[:start_at] > now }.min_by { |session| session[:start_at] }
  end

  private

  def talk_entry(talk, track_lookup)
    track_name = talk.static_metadata&.track
    track = track_name && track_lookup[track_name]

    {
      title: talk.title,
      speakers: talk.speakers.map(&:name),
      speaker_avatars: talk.speakers.map(&:avatar_url).compact,
      track: track_name,
      track_color: track&.dig("color"),
      track_text_color: track&.dig("text_color")
    }
  end

  def parse_local_time(zone, date, time)
    return nil if date.blank? || time.blank?

    zone.parse("#{date} #{time}")
  rescue ArgumentError
    nil
  end
end
