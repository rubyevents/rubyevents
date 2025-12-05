series_slug = ARGV[0]

videos_to_ignore = YAML.load_file("#{Rails.root}/data/videos_to_ignore.yml")

if series_slug.blank?
  data_dir = Rails.root.join("data")
  series_slugs = Static::EventSeries.all.map(&:slug).sort

  series_slug = IO.popen(["fzy"], "r+") do |fzy|
    fzy.puts(series_slugs.join("\n"))
    fzy.close_write
    fzy.gets&.strip
  end

  if series_slug.blank?
    puts "No series selected"
    exit 1
  end
end

series = Static::EventSeries.all.to_a.find { |series| series.slug == series_slug }

raise "uhoh #{series_slug} not present" if series.nil?

series_file_path = "#{Rails.root}/data/#{series.slug}/series.yml"

series = YAML.load_file(series_file_path)
series_slug = File.basename(File.dirname(series_file_path))
event_series = EventSeries.find_or_initialize_by(slug: series_slug)
event_files = Dir.glob("#{Rails.root}/data/#{event_series.slug}/*/event.yml")

event_series.update!(
  name: series["name"],
  website: series["website"],
  twitter: series["twitter"] || "",
  youtube_channel_name: series["youtube_channel_name"],
  kind: series["kind"],
  frequency: series["frequency"],
  youtube_channel_id: series["youtube_channel_id"],
  slug: series_slug,
  language: series["language"] || ""
)

event_series.sync_aliases_from_list(series["aliases"]) if series["aliases"].present?

event_files.each do |event_file_path|
  event_data = YAML.load_file(event_file_path)
  event_slug = File.basename(File.dirname(event_file_path))
  event = Event.find_or_create_by(slug: event_slug)

  event.update(
    name: event_data["title"],
    date: event_data["date"] || event_data["published_at"],
    date_precision: event_data["date_precision"] || "day",
    series: event_series,
    website: event_data["website"],
    country_code: event.static_metadata.country&.alpha2,
    start_date: event.static_metadata.start_date,
    end_date: event.static_metadata.end_date,
    kind: event.static_metadata.kind
  )

  event.sync_aliases_from_list(event_data["aliases"]) if event_data["aliases"].present?

  puts event.slug unless Rails.env.test?

  cfp_file_path = "#{Rails.root}/data/#{event_series.slug}/#{event.slug}/cfp.yml"

  if File.exist?(cfp_file_path)
    cfps = YAML.load_file(cfp_file_path)

    cfps.each do |cfp_data|
      event.cfps.find_or_create_by(
        link: cfp_data["link"],
        open_date: cfp_data["open_date"]
      ).update(
        name: cfp_data["name"],
        close_date: cfp_data["close_date"]
      )
    end
  end

  if event.videos_file?
    event.videos_file.each do |talk_data|
      if talk_data["title"].blank? || videos_to_ignore.include?(talk_data["video_id"])
        puts "Ignored video: #{talk_data["raw_title"]}"
        next
      end

      talk = Talk.find_or_initialize_by(static_id: talk_data["id"])
      talk.update_from_yml_metadata!(event: event)

      child_talks = talk_data["talks"]

      next unless child_talks

      Array.wrap(child_talks).each do |child_talk_data|
        child_talk = Talk.find_or_initialize_by(static_id: child_talk_data["id"])
        child_talk.parent_talk = talk
        child_talk.update_from_yml_metadata!(event: event)
      end
    rescue ActiveRecord::RecordInvalid => e
      puts "Couldn't save: #{talk_data["title"]} (#{talk_data["id"]}), error: #{e.message}"
    end
  end

  if event.sponsors_file.exist?
    event.sponsors_file.file.each do |sponsors|
      sponsors["tiers"].each do |tier|
        tier["sponsors"].each do |sponsor|
          s = nil
          domain = nil

          if sponsor["website"].present?
            begin
              uri = URI.parse(sponsor["website"])
              host = uri.host || sponsor["website"]
              parsed = PublicSuffix.parse(host)
              domain = parsed.domain

              s = Organization.find_by(domain: domain) if domain.present?
            rescue PublicSuffix::Error, URI::InvalidURIError
              # If parsing fails, continue with other matching methods
            end
          end

          s ||= Organization.find_by(name: sponsor["name"]) || Organization.find_by(slug: sponsor["slug"]&.downcase)
          s ||= Organization.find_or_initialize_by(name: sponsor["name"])

          s.update(
            website: sponsor["website"],
            description: sponsor["description"],
            domain: domain
            # s.level = sponsor["level"]
            # s.event = event
            # s.organisation = organisation
          )

          s.add_logo_url(sponsor["logo_url"]) if sponsor["logo_url"].present?
          s.logo_url = sponsor["logo_url"] if sponsor["logo_url"].present? && s.logo_url.blank?

          if !s.persisted?
            s = Organization.find_by(slug: s.slug) || Organization.find_by(name: s.name)
          end

          s.save!

          event.sponsors.find_or_create_by!(organization: s, event: event).update!(tier: tier["name"], badge: sponsor["badge"])
        end
      end
    end
  end
end
