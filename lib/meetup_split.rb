# frozen_string_literal: true

# Turns every meetup group's single event, which held all its meetups as talks with nested talks in one videos.yml,
# into one event per meetup in data/{series}/{series}-{YYYY-MM-DD}/, and moves what belongs to the group into the series.
#
#   bin/rails meetups:split DRY_RUN=1
#   bin/rails meetups:split ONLY=lrug-meetup,chicagoruby-meetup
#
# The series gets the group's description, links, location and colors, its cfp, sponsors and involvements, and its images
# as series defaults. The group event's id goes into `old_event_ids`, and each meetup that was a talk with nested talks
# lists that talk's ids in `old_talk_ids`, so the next seed redirects their URLs. Meetups with their own recording keep
# that recording, with its id, in their videos.yml.
#
class MeetupSplit
  SERIES_FIELDS = (MeetupLinks::FIELDS + %w[
    description original_website github twitter mastodon
    banner_background featured_background featured_color location timezone coordinates playlist
  ]).freeze

  SERIES_LIST_FIELDS = %w[aliases youtube_channels feeds].freeze
  SERIES_FILES = %w[cfp.yml sponsors.yml involvements.yml].freeze
  COLLECTIBLES = /\A(sticker|stamp)/
  DATE_TOLERANCE = 2

  SERIES_OVERRIDES = {
    "lyonrb" => {"website" => "https://www.lyonrb.fr", "meetup" => "https://www.meetup.com/LyonRB"},
    "ruby-montevideo" => {"website" => "https://ruby.uy", "meetup" => "https://www.meetup.com/ruby-montevideo"},
    "ruby-turkiye" => {"kommunity" => "https://kommunity.com/ruby-turkiye"},
    "bangkok-rb" => {"meetup" => "https://www.meetup.com/bangkok-rb/"}
  }.freeze

  attr_reader :report

  def initialize(dry_run: false, only: nil, root: Rails.root)
    @dry_run = dry_run
    @only = Array(only).compact_blank
    @root = Pathname.new(root.to_s)
    @report = Hash.new { |hash, key| hash[key] = [] }
  end

  def run
    groups.each { |group| split(group) }

    report
  end

  def import(file, series_slug:)
    series = Static::EventSeries.find_by_slug(series_slug) or raise ArgumentError, "Event series '#{series_slug}' not found"
    used_folders = series.events.map { |event| event["id"] }.to_set
    known_ids = series.events.flat_map(&:old_talk_ids).to_set

    imported = false

    Static::Talk.in_file(file.to_s).top_level.each do |edition|
      next if known_ids.include?(edition.id) || known_ids.include?(edition["old_id"])
      next if used_folders.include?("#{series.slug}-#{edition["date"]}")

      meetup = plan_meetup(series, edition, series.slug, used_folders)

      meetup[:attributes].delete("old_talk_ids")

      log(:imported, "#{edition.id} -> #{series.directory}/#{meetup[:folder]}")
      next if @dry_run

      directory = write_meetup(series, meetup)
      name_talks(File.join(directory, "videos.yml"))
      imported = true
    end

    title_meetups(series) if imported

    report
  end

  def title_meetups(series)
    Static::Validators::MeetupTitle.reset_meetup_dates!

    Dir.glob(File.join(File.dirname(series.file_path), "*", "event.yml")).each do |path|
      Static::Validators::MeetupTitle.new(file_path: path).fix
    end
  end

  def name_talks(path)
    return unless File.exist?(path)

    Static::Validators::TalkId.new(file_path: path).fix
    Static::Validators::TalkVideoId.new(file_path: path).fix
  end

  def self.normalize_top_level_talks!(path, kind: nil, language: nil, dates: nil)
    talks = Static::Talk.in_file(path.to_s).top_level.to_a
    changed = false

    talks.each do |talk|
      unless talk.key?("description")
        talk.set("description", "")
        changed = true
      end

      if dates && (talk["date"].blank? || !talk["date"].to_s.between?(*dates))
        talk.set("date", dates.first)
        changed = true
      end

      %w[start_cue end_cue thumbnail_cue].each do |cue|
        next unless talk.key?(cue)

        talk.delete(cue)
        changed = true
      end

      if kind.present? && talk["kind"].blank?
        talk.set("kind", kind)
        changed = true
      end

      if language.present? && talk["language"].blank?
        talk.set("language", language)
        changed = true
      end

      # "2026-08-12 19:28:00 +0000" from the LRUG playlist, stored like every other timestamp
      announced_at = talk["announced_at"].to_s
      if announced_at.present? && !announced_at.match?(/\A\d{4}-\d{2}-\d{2}(T\d{2}:\d{2}:\d{2}Z)?\z/)
        talk.set("announced_at", Time.parse(announced_at).utc.iso8601)
        changed = true
      end
    end

    talks.first.document.save!(apply: true) if changed && talks.any?
  end

  def groups
    Static::Event.all.select(&:meetup?)
      .reject { |event| Static::Validators::MeetupNaming.ignored?(event) }
      .select { |event| event["start_date"].blank? }
      .select { |event| @only.empty? || @only.include?(event["id"]) }
  end

  def split(group)
    plan = plan_for(group)

    log(:groups, "#{group["id"]} -> #{plan[:series_directory]} (#{plan[:meetups].size} meetups#{", new series" if plan[:new_series]})")
    return if @dry_run

    series = write_series(group, plan)
    move_series_files(group, plan)
    move_images(group, plan)
    plan[:meetups].each { |meetup| write_meetup(series, meetup) }
    move_remaining_thumbnails(group)
    remove_group(group)
  end

  def self.embedded_links(description, ambiguous: false)
    found = MeetupLinks::EVENT_URLS.transform_values do |pattern|
      description.scan(pattern).map { |url| url.sub(%r{\Ahttps?://(www\.)?lu\.ma/}, "https://luma.com/").delete_suffix("/") }.uniq
    end

    if ambiguous
      found.select { |_field, urls| urls.size > 1 }
    else
      found.select { |_field, urls| urls.one? }.transform_values(&:first)
    end
  end

  private

  def plan_for(group)
    series = group.series
    series_id, new_series, parent = target_series(group, series)
    parent_path = new_series ? parent&.directory : series&.parent_path
    series_directory = [parent_path, series_id].compact_blank.join("/")

    used_folders = Set.new
    meetups = group.talks.top_level.map { |edition| plan_meetup(group, edition, series_id, used_folders) }

    {series_id: series_id, new_series: new_series, parent: parent, series_directory: series_directory, meetups: meetups}
  end

  def target_series(group, series)
    return [group.path_params[:series_id], true, nil] if series.nil?

    others = series.events.reject { |event| event["id"] == group["id"] }
    return [series.slug, false, nil] if series["kind"] == "meetup" && others.empty?

    stripped = group["id"].delete_suffix("-meetup")
    candidate = (stripped != series.slug && Static::EventSeries.find_by_slug(stripped).nil?) ? stripped : group["id"]

    [candidate, true, series]
  end

  def plan_meetup(group, edition, series_id, used_folders)
    talks = edition.talks.to_a
    date = Date.parse(edition["date"].to_s)
    talk_dates = talks.filter_map { |talk|
      begin
        Date.parse(talk["date"].to_s)
      rescue
        nil
      end
    }

    close_dates = talk_dates.select { |talk_date| (talk_date - date).abs <= DATE_TOLERANCE }
    start_date = [date, *close_dates].min
    end_date = [date, *close_dates].max

    (talk_dates - close_dates).each do |far|
      log(:dates, "#{edition.id}: a talk on #{far} is far from the meetup on #{date}, moved to the meetup's date")
    end

    base = "#{series_id}-#{start_date.iso8601}"
    folder = used_folders.include?(base) ? "#{base}-#{(2..).find { |counter| !used_folders.include?("#{base}-#{counter}") }}" : base
    used_folders << folder

    keep_recording = edition["video_provider"] != "children" || talks.any? { |talk| talk["video_provider"] == "parent" }
    log(:recordings, "#{edition.id}: keeps its #{edition["video_provider"]} entry") if keep_recording && edition["video_provider"] == "children"

    description, links = extract_links(edition["description"].to_s)
    links = self.class.embedded_links(description).merge(links)
    links = links.reject { |field, url| group_links(group, field).include?(url.chomp("/")) }
    location, _venue = meetup_location(group, edition)

    attributes = {
      "kind" => "meetup",
      "location" => location || group["location"],
      "timezone" => group["timezone"],
      "description" => description.presence,
      "start_date" => start_date.iso8601,
      "end_date" => end_date.iso8601,
      "start_time" => edition["start_time"],
      "end_time" => edition["end_time"],
      "announced_on" => edition["announced_at"].to_s[0, 10].presence,
      "status" => edition["status"],
      "additional_resources" => edition["additional_resources"].presence,
      "old_talk_ids" => (keep_recording ? nil : [edition.id, edition["old_id"]].compact_blank.uniq),
      "coordinates" => meetup_coordinates(group, location)
    }.merge(links).compact

    speakers = Array(edition["speakers"]) - ["TODO"]

    log(:speakers, "#{edition.id}: edition speakers #{speakers.join(", ")} need a home (involvements?)") if speakers.any?
    log(:thumbnails, "#{edition.id}: drops its #{edition["video_provider"]} thumbnail urls") if !keep_recording && edition["thumbnail_xs"].present?

    sources = keep_recording ? [edition.node.source] : talks.map { |talk| talk.node.source }

    {
      folder: folder,
      title: edition["title"],
      attributes: attributes,
      sources: sources,
      kind: edition["kind"],
      language: edition["language"],
      edition_id: edition.id,
      keep_recording: keep_recording,
      group_id: group["id"],
      series_id: series_id
    }
  end

  def extract_links(description)
    lines = description.rstrip.lines.map(&:rstrip)
    links = {}
    leftovers = []

    while (url = lines.last&.strip) && url.match?(%r{\Ahttps?://\S+\z})
      lines.pop

      field = MeetupLinks.field_for(url)
      value = (field == "luma") ? url.sub(%r{\Ahttps?://(www\.)?lu\.ma/}, "https://luma.com/") : url

      if links[field].nil?
        links[field] = value
      else
        leftovers.unshift(url)
      end
    end

    lines.pop while lines.last&.strip == ""
    lines.concat(["", *leftovers]) if leftovers.any?

    [lines.join("\n").strip, links]
  end

  def group_links(group, field)
    [group[field], (group.series[field] if group.respond_to?(:series) && group.series)].compact.map { |url| url.to_s.chomp("/") }
  end

  def meetup_location(group, edition)
    value = edition["location"].to_s.strip
    return [nil, nil] if value.blank? || value == group["location"]
    return ["online", nil] if value.casecmp?("online")

    parts = value.split(",").map(&:strip)
    country = Country.find(parts.last)
    venue = nil

    if parts.size == 3 && country && !State.supported_country?(country)
      venue = parts.shift
    end

    city_like = parts.size.between?(2, 3) && parts.none? { |part| part.match?(/\d/) } && country.present?
    return [nil, value] unless city_like

    location = parts.join(", ")
    return [nil, venue] if parts.first == group["location"].to_s.split(",").first&.strip

    log(:locations, "#{edition.id}: in #{location}#{" at #{venue}" if venue}, not #{group["location"]}")

    [location, venue]
  end

  def meetup_coordinates(group, location)
    return false if location == "online"
    return nil if location.present?

    group["coordinates"].presence
  end

  def write_series(group, plan)
    series = if plan[:new_series]
      Static::EventSeries.create(
        name: group["title"].to_s.sub(/\s+Meetup\z/i, ""),
        slug: plan[:series_id],
        parent: plan[:parent],
        kind: "meetup",
        language: plan[:parent]&.[]("language"),
        default_country_code: plan[:parent]&.[]("default_country_code")
      )
    else
      Static::EventSeries.find_by_slug(plan[:series_id])
    end

    SERIES_FIELDS.each do |field|
      value = group[field]
      next if value.blank? && value != false

      current = series[field]

      if current.blank? && current != false
        series.set(field, value)
      elsif current != value
        log(:conflicts, "#{series.slug}: keeps #{field} #{current.inspect}, the group event had #{value.inspect}")
      end
    end

    SERIES_LIST_FIELDS.each do |field|
      values = (Array(series[field]) + Array(group[field])).uniq
      series.set(field, values) if values.any? && values != Array(series[field])
    end

    old_event_ids = (series.old_event_ids + [group["id"], *group.old_ids]).uniq
    series.set("old_event_ids", old_event_ids)

    removed_talk_ids = (Array(series["removed_talk_ids"]) + Array(group["removed_talk_ids"])).uniq
    series.set("removed_talk_ids", removed_talk_ids) if removed_talk_ids.any?

    SERIES_OVERRIDES.fetch(series.slug, {}).each { |field, value| series.set(field, value) }

    %w[tickets_url year].each do |field|
      log(:dropped, "#{group["id"]}: drops #{field} #{group[field].inspect}") if group[field].present?
    end

    series.save!

    Static::EventSeries.unload!
    Static::EventSeries.find_by_slug(plan[:series_id])
  end

  def move_series_files(group, plan)
    group_directory = File.dirname(group.file_path)
    series_directory = @root.join("data", plan[:series_directory])

    SERIES_FILES.each do |file|
      source = File.join(group_directory, file)
      next unless File.exist?(source)

      target = series_directory.join(file)
      next if source == target.to_s

      if target.exist?
        log(:conflicts, "#{plan[:series_id]}: already has #{file}, left #{group["id"]}/#{file} in place")
      else
        FileUtils.mv(source, target)
      end
    end

    venue = File.join(group_directory, "venue.yml")
    log(:venues, "#{group["id"]}: has a venue.yml, copied into each of its meetups") if File.exist?(venue)
    @group_venue = File.exist?(venue) ? File.read(venue) : nil
  end

  def move_images(group, plan)
    source_directory = @root.join("app/assets/images/events", group.path_params[:series_id], group["id"])
    return unless source_directory.directory?

    series_directory = @root.join("app/assets/images/events", plan[:series_id])

    source_directory.children.select(&:file?).each do |file|
      target = file.basename.to_s.match?(COLLECTIBLES) ? series_directory.join(file.basename) : series_directory.join("default", file.basename)

      if target.exist?
        log(:conflicts, "#{plan[:series_id]}: already has #{target.relative_path_from(@root)}, kept it over #{file.relative_path_from(@root)}")
        file.delete
      else
        FileUtils.mkdir_p(target.dirname)
        FileUtils.mv(file, target)
      end
    end

    source_directory.rmdir if source_directory.empty?
  end

  def write_meetup(series, meetup)
    event = Static::Event.create(
      series_slug: series.slug,
      title: meetup[:title],
      slug: meetup[:folder],
      videos_file: false,
      **meetup[:attributes].symbolize_keys
    )

    directory = File.dirname(event.file_path)

    write_videos(directory, meetup, series) if meetup[:sources].any?
    File.write(File.join(directory, "venue.yml"), @group_venue) if @group_venue

    move_thumbnails(meetup, event.slug) if meetup[:keep_recording]

    directory
  end

  def write_videos(directory, meetup, series)
    items = meetup[:sources].map { |source| top_level_item(source) }
    path = File.join(directory, "videos.yml")

    File.write(path, "---\n#{items.join("\n\n")}\n")

    self.class.normalize_top_level_talks!(path, kind: meetup[:keep_recording] ? nil : meetup[:kind], language: (meetup[:language] if meetup[:language] != series["language"]), dates: meetup[:attributes].values_at("start_date", "end_date"))
  end

  def top_level_item(source)
    lines = source.lines.map(&:rstrip)
    indents = lines.drop(1).reject(&:empty?).map { |line| line[/\A */].size }
    shift = [(indents.min || 2) - 2, 0].max

    lines = lines.each_with_index.map { |line, index| (index.zero? || line.empty?) ? line : line.delete_prefix(" " * shift) }
    lines.reject { |line| line.match?(/\A\s*event_name: [^|>].*\z/) }.join("\n")
  end

  def move_thumbnails(meetup, slug)
    source = @root.join("app/assets/images/thumbnails", meetup[:group_id], meetup[:edition_id])
    return unless source.directory?

    target = @root.join("app/assets/images/thumbnails", slug, meetup[:edition_id])
    FileUtils.mkdir_p(target.dirname)
    FileUtils.mv(source, target)
  end

  def move_remaining_thumbnails(group)
    source = @root.join("app/assets/images/thumbnails", group["id"])
    return unless source.directory?

    Static::Talk.unload!
    talks = Static::Talk.all.reject { |talk| talk.path_params[:event_id] == group["id"] }
    talks_by_video_id = talks.index_by { |talk| talk["video_id"].to_s.unicode_normalize(:nfc) }

    source.glob("**/*.webp").each do |file|
      talk = talks_by_video_id[file.basename(".webp").to_s.unicode_normalize(:nfc)]

      unless talk
        log(:thumbnails, "#{file.relative_path_from(@root)}: no talk with this video id, left in place")
        next
      end

      if talk.parent.nil? && talk["start_cue"].blank? && Static::Validators::RedundantThumbnails::REMOTE_THUMBNAIL_PROVIDERS.include?(talk["video_provider"])
        file.delete
        next
      end

      target = @root.join("app/assets/images/thumbnails", *[talk.event_slug, talk.parent&.id, file.basename.to_s].compact)
      next if target == file

      FileUtils.mkdir_p(target.dirname)
      FileUtils.mv(file, target)
    end

    source.glob("**/").sort.reverse_each { |directory| directory.rmdir if directory.empty? }
  end

  def remove_group(group)
    directory = Pathname.new(File.dirname(group.file_path))

    %w[event.yml videos.yml venue.yml].each { |file| directory.join(file).delete if directory.join(file).exist? }
    directory.rmdir if directory.empty?

    thumbnails = @root.join("app/assets/images/thumbnails", group["id"])
    thumbnails.rmdir if thumbnails.directory? && thumbnails.empty?

    @group_venue = nil
    Static::Event.unload!
    Static::Talk.unload!
  end

  def log(section, message)
    report[section] << message
  end
end
