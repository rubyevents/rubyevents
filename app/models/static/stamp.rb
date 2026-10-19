# frozen_string_literal: true

module Static
  class Stamp < Yerba::Record::FileRecord
    types "Static::CountryStamp", "Static::UKNationStamp", "Static::EventStamp", "Static::AchievementStamp"

    self.order_by = :name

    UK_SUBDIVISION_CODES = %w[GB-SCT GB-ENG GB-NIR GB-WLS].freeze

    def self.country_stamps
      all.select(&:has_country?)
    end

    def self.event_stamps
      Static::EventStamp.all.to_a
    end

    def self.achievement(code)
      Static::AchievementStamp.all.find { |stamp| stamp.code == code }
    end

    def self.contributor_stamp = achievement("RUBYEVENTS-CONTRIBUTOR")
    def self.passport_stamp = achievement("RUBY-PASSPORT")
    def self.triathlon_2025_stamp = achievement("RUBY-TRIATHLON-2025")
    def self.conference_speaker_stamp = achievement("SPEAK-AT-A-CONFERENCE")
    def self.meetup_speaker_stamp = achievement("SPEAK-AT-A-MEETUP")
    def self.attend_one_event_stamp = achievement("ATTEND-ONE-EVENT")
    def self.ruby_30th_anniversary = achievement("RUBY-30TH-ANNIVERSARY")
    def self.online_stamp = achievement("ONLINE")

    def self.for(country_code: nil, state_code: nil, events: nil)
      if events
        stamps = events.flat_map do |event|
          next [] unless event.country

          self.for(country_code: event.country_code, state_code: event.state_code)
        end

        return stamps.uniq(&:code)
      end

      stamps = country_stamps.select { |stamp| stamp.code == country_code }

      if country_code == "GB" && state_code.present?
        uk_nation = ::UKNation.find_by_code(state_code)
        stamps.concat(uk_nation.stamps) if uk_nation
      end

      stamps
    end

    def self.for_user(user)
      user_events = user.all_attended_events
      stamps = self.for(events: user_events).to_a
      stamps = (stamps + user_events.flat_map { |event| for_event(event) }).uniq(&:code)

      stamps << contributor_stamp if user.contributor? && contributor_stamp
      stamps << passport_stamp if user.ruby_passport_claimed? && passport_stamp
      stamps << triathlon_2025_stamp if user_attended_triathlon_2025?(user_events) && triathlon_2025_stamp
      stamps << conference_speaker_stamp if user.speaking_events.where(kind: :conference).exists? && conference_speaker_stamp
      stamps << meetup_speaker_stamp if user.speaking_events.where(kind: :meetup).exists? && meetup_speaker_stamp
      stamps << attend_one_event_stamp if user_events.where(kind: :conference).exists? && attend_one_event_stamp
      stamps << online_stamp if user_events.any? { |event| event.location == "Online" } && online_stamp

      stamps
    end

    def self.for_event(event)
      return [] unless event&.slug

      event_stamps.select { |stamp| stamp.event_id == event.slug }
    end

    def self.user_attended_triathlon_2025?(user_events)
      required_event_slugs = ["rails-world-2025", "friendly-rb-2025", "euruko-2025"]
      attended_event_slugs = user_events.pluck(:slug)

      required_event_slugs.all? { |slug| attended_event_slugs.include?(slug) }
    end

    def self.grouped_by_continent
      stamps_by_continent = country_stamps.group_by { |stamp| stamp.country&.continent_name }
      custom_stamps = all.reject(&:has_country?).reject(&:has_event?)

      stamps_by_continent["Custom"] = custom_stamps if custom_stamps.any?

      stamps_by_continent
    end

    def self.missing_for_events
      event_countries = ::Event.all.map(&:country).compact.uniq
      stamp_countries = country_stamps.map(&:country).compact.uniq
      gb_country = ::Country.find_by(country_code: "GB")
      uk_subdivisions_covered = all.any? { |stamp| UK_SUBDIVISION_CODES.include?(stamp.code) }

      event_countries.reject { |event_country|
        stamp_countries.any? { |stamp_country| stamp_country.alpha2 == event_country.alpha2 } || (event_country.alpha2 == gb_country&.alpha2 && uk_subdivisions_covered)
      }.sort_by(&:name)
    end

    def owner
      nil
    end

    def code
      basename.upcase
    end

    def name
      country&.name || basename.titleize
    end

    def country
      owner if owner.is_a?(::Country) || owner.is_a?(::UKNation)
    end

    def has_country?
      country.present?
    end

    def has_event?
      false
    end

    def event
      nil
    end

    def image_path
      path.relative_path_from(Pathname.new(path_root.to_s).join("app/assets/images")).to_s
    end

    def asset_path
      Router.asset_path(image_path)
    end
  end
end
