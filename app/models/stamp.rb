class Stamp
  include ActiveModel::Model
  include ActiveModel::Attributes

  attribute :code, :string
  attribute :name, :string
  attribute :file_path, :string
  attribute :country
  attribute :has_country, :boolean, default: false

  class << self
    def all
      @all_stamps ||= load_stamps_from_filesystem
    end

    def country_stamps
      @country_stamps ||= all.select(&:has_country?)
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
      stamps = self.for(events: user.participated_events).to_a

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
      custom_stamps = all.reject(&:has_country?)

      stamps_by_continent["Custom"] = custom_stamps if custom_stamps.any?

      stamps_by_continent
    end

    def missing_for_events
      event_countries = Event.all.map { |event| event.country }.compact.uniq
      stamp_countries = all.select(&:has_country?).map(&:country).compact.uniq

      event_countries.reject { |event_country|
        stamp_countries.include?(event_country) || (event_country == ISO3166::Country.new("GB") && uk_subdivisions_covered?)
      }.sort_by { |c| c.translations["en"] }
    end
  end

  def asset_path
    ActionController::Base.helpers.asset_path("stamps/#{File.basename(file_path)}")
  end

  def has_country?
    has_country
  end

  def self.load_stamps_from_filesystem
    stamps_directory = Rails.root.join("app", "assets", "images", "stamps")
    return [] unless File.directory?(stamps_directory)

    stamp_files = Dir.glob(File.join(stamps_directory, "*.webp")).map { |file| File.basename(file, ".webp") }

    stamp_files.map { |stamp_code| create_stamp_from_code(stamp_code) }.compact.sort_by(&:name)
  end

  def self.create_stamp_from_code(stamp_code)
    stamp_upper = stamp_code.upcase
    file_path = "#{stamp_code}.webp"

    case stamp_upper
    when "SCT", "SCOTLAND", "GB-SCT"
      new(
        code: "SCT",
        name: "Scotland",
        file_path: file_path,
        country: ISO3166::Country.new("GB"),
        has_country: true
      )
    when "ENG", "ENGLAND", "GB-ENG"
      new(
        code: "ENG",
        name: "England",
        file_path: file_path,
        country: ISO3166::Country.new("GB"),
        has_country: true
      )
    when "NIR", "NI", "NORTHERN-IRELAND", "GB-NIR"
      new(
        code: "NIR",
        name: "Northern Ireland",
        file_path: file_path,
        country: ISO3166::Country.new("GB"),
        has_country: true
      )
    when "WLS", "WALES", "GB-WLS"
      new(
        code: "WLS",
        name: "Wales",
        file_path: file_path,
        country: ISO3166::Country.new("GB"),
        has_country: true
      )
    else
      country = ISO3166::Country.new(stamp_upper)
      if country
        new(
          code: stamp_upper,
          name: country.translations["en"],
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
  end

  def self.uk_subdivisions_covered?
    uk_subdivision_codes = ["SCT", "ENG", "NIR", "WLS"]

    all.any? { |stamp| uk_subdivision_codes.include?(stamp.code) }
  end
end
