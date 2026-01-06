class Stamp
  include ActiveModel::Model
  include ActiveModel::Attributes

  attribute :code, :string
  attribute :name, :string
  attribute :file_path, :string
  attribute :country
  attribute :has_country, :boolean, default: false
  attribute :has_event, :boolean, default: false
  attribute :event
  attribute :event_slug, :string

  class << self
    def all
      @all_stamps ||= load_stamps_from_filesystem
    end

    def country_stamps
      @country_stamps ||= all.select(&:has_country?)
    end

    def event_stamps
      @event_stamps ||= all.select(&:has_event?)
    end

    def contributor_stamp
      @contributor_stamp ||= all.find { |s| s.code == "RUBYEVENTS-CONTRIBUTOR" }
    end

    def passport_stamp
      @passport_stamp ||= all.find { |s| s.code == "RUBY-PASSPORT" }
    end

    def triathlon_2025_stamp
      @triathlon_2025_stamp ||= all.find { |s| s.code == "RUBY-TRIATHLON-2025" }
    end

    def conference_speaker_stamp
      @conference_speaker_stamp ||= all.find { |s| s.code == "SPEAK-AT-A-CONFERENCE" }
    end

    def meetup_speaker_stamp
      @meetup_speaker_stamp ||= all.find { |s| s.code == "SPEAK-AT-A-MEETUP" }
    end

    def attend_one_event_stamp
      @attend_one_event_stamp ||= all.find { |s| s.code == "ATTEND-ONE-EVENT" }
    end

    def online_stamp
      @online_stamp ||= all.find { |s| s.code == "ONLINE" }
    end

    def for_country(country)
      country_stamps.find { |s| s.code == country }
    end

    def for(events:)
      event_countries = events.map { |event| event.country }.compact.uniq
      all.select { |stamp| stamp.has_country? && event_countries.include?(stamp.country) }
    end

    def for_user(user)
      user_events = user.participated_events
      stamps = self.for(events: user_events).to_a

      event_stamps_for_user = user_events.flat_map { |event| for_event(event) }
      stamps = (stamps + event_stamps_for_user).uniq { |stamp| stamp.code }

      if user.contributor? && contributor_stamp
        stamps << contributor_stamp
      end

      if user.passports.any? && passport_stamp
        stamps << passport_stamp
      end

      if user_attended_triathlon_2025?(user) && triathlon_2025_stamp
        stamps << triathlon_2025_stamp
      end

      if user_spoke_at_conference?(user) && conference_speaker_stamp
        stamps << conference_speaker_stamp
      end

      if user_spoke_at_meetup?(user) && meetup_speaker_stamp
        stamps << meetup_speaker_stamp
      end

      if user_attended_conference?(user) && attend_one_event_stamp
        stamps << attend_one_event_stamp
      end

      if user_attended_online_event?(user) && online_stamp
        stamps << online_stamp
      end

      stamps
    end

    def for_event(event)
      return [] unless event&.slug

      prefix = "#{event.event_image_path}/"

      event_stamps.select { |stamp|
        (stamp.event_slug.present? && stamp.event_slug == event.slug) ||
          stamp.file_path.start_with?(prefix)
      }
    end

    def user_attended_triathlon_2025?(user)
      required_event_slugs = ["rails-world-2025", "friendly-rb-2025", "euruko-2025"]
      attended_event_slugs = user.participated_events.pluck(:slug)

      required_event_slugs.all? { |slug| attended_event_slugs.include?(slug) }
    end

    def user_spoke_at_conference?(user)
      user.speaker_events.where(kind: :conference).exists?
    end

    def user_spoke_at_meetup?(user)
      user.speaker_events.where(kind: :meetup).exists?
    end

    def user_attended_conference?(user)
      user.participated_events.where(kind: :conference).exists?
    end

    def user_attended_online_event?(user)
      user.participated_events.any? { |event| event.static_metadata&.location == "Online" }
    end

    def grouped_by_continent
      stamps_by_continent = all.select(&:has_country?).group_by { |stamp| stamp.country&.continent }
      custom_stamps = all.reject(&:has_country?).reject(&:has_event?)

      stamps_by_continent["Custom"] = custom_stamps if custom_stamps.any?

      stamps_by_continent
    end

    def missing_for_events
      event_countries = Event.all.map(&:country).compact.uniq
      stamp_countries = all.select(&:has_country?).map(&:country).compact.uniq
      gb_country = Country.find_by(country_code: "GB")

      event_countries.reject { |event_country|
        stamp_countries.any? { |sc| sc.alpha2 == event_country.alpha2 } ||
          (event_country.alpha2 == gb_country&.alpha2 && uk_subdivisions_covered?)
      }.sort_by(&:name)
    end
  end

  def asset_path
    relative_path = file_path.to_s

    if relative_path.include?(File::SEPARATOR) || (File::ALT_SEPARATOR && relative_path.include?(File::ALT_SEPARATOR))
      ActionController::Base.helpers.asset_path(relative_path)
    else
      ActionController::Base.helpers.asset_path("stamps/#{relative_path}")
    end
  end

  def has_country?
    has_country
  end

  def has_event?
    has_event
  end

  def event
    return @event if defined?(@event)

    @event = Event.find_by(slug: event_slug) if event_slug.present?
  end

  def self.load_stamps_from_filesystem
    images_directory = Rails.root.join("app", "assets", "images")
    stamps_directory = images_directory.join("stamps")

    static_stamps =
      if File.directory?(stamps_directory)
        Dir.glob(stamps_directory.join("*.webp")).map { |file| File.basename(file, ".webp") }
      else
        []
      end

    event_stamp_files = Dir.glob(images_directory.join("events", "**", "stamp*.webp"))

    (static_stamps.map { |stamp_code| create_stamp_from_code(stamp_code) } +
      event_stamp_files.map { |file| create_stamp_from_event_file(file, images_directory) })
      .compact
      .uniq { |stamp| stamp.code }
      .sort_by(&:name)
  end

  def self.create_stamp_from_code(stamp_code)
    stamp_upper = stamp_code.upcase
    file_path = "#{stamp_code}.webp"
    country = Country.find_by(country_code: stamp_upper)

    if country
      new(
        code: stamp_upper,
        name: country.name,
        file_path: file_path,
        country: country,
        has_country: true
      )
    else
      new(
        code: stamp_upper,
        name: stamp_code.titleize,
        file_path: file_path,
        country: nil,
        has_country: false
      )
    end
  end

  def self.create_stamp_from_event_file(file, images_directory)
    relative_path = Pathname.new(file).relative_path_from(images_directory)
    path_parts = relative_path.each_filename.to_a
    event_slug = path_parts[-2]
    basename = Pathname.new(file).basename(".webp").to_s

    return nil unless event_slug.present? && basename.present?

    event = Event.find_by(slug: event_slug)

    variant_suffix = basename.sub(/^stamp[_-]?/i, "")
    code_parts = [event&.slug || event_slug, basename].compact
    code = code_parts.join("-").upcase

    display_name = event&.name || event_slug.titleize
    variant_label = variant_suffix.present? ? "Stamp #{variant_suffix.titleize}" : "Stamp"
    name = "#{display_name} (#{variant_label})"

    new(
      code: code,
      name: name,
      file_path: relative_path.to_s,
      country: event&.country,
      has_country: false,
      has_event: true,
      event: event,
      event_slug: event_slug
    )
  end

  def self.uk_subdivisions_covered?
    uk_subdivision_codes = ["SCT", "ENG", "NIR", "WLS"]

    all.any? { |stamp| uk_subdivision_codes.include?(stamp.code) }
  end
end
