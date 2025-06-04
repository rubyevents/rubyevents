module Static
  class Playlist < FrozenRecord::Base
    include ActionView::Helpers::DateHelper

    self.backend = Backends::MultiFileBackend.new("**/**/playlists.yml")
    self.base_path = Rails.root.join("data")

    def future?
      if start_date.present?
        start_date.future?
      elsif event_record.present?
        event_record.start_date.future?
      else
        false
      end
    end

    def featured?
      within_next_days? || today? || past?
    end

    def today?
      if start_date.present?
        return start_date.today?
      end

      if end_date.present?
        return end_date.today?
      end

      if event_record.present? && event_record.start_date
        return event_record.start_date.today?
      end

      if event_record.present? && event_record.end_date
        return event_record.end_date.today?
      end

      false
    end

    def within_next_days?
      period = 4.days

      if end_date.present?
        return ((end_date - period)..end_date).cover?(Date.today)
      end

      if start_date.present?
        return ((start_date - period)..start_date).cover?(Date.today)
      end

      if event_record.present? && event_record.start_date
        return ((event_record.start_date - period)..event_record.start_date).cover?(Date.today)
      end

      if event_record.present? && event_record.end_date
        return ((event_record.end_date - period)..event_record.end_date).cover?(Date.today)
      end

      false
    end

    def past?
      if end_date.present?
        end_date.past?
      elsif event_record.present? && event_record.end_date.present?
        event_record.end_date.past?
      else
        false
      end
    end

    def conference?
      kind == "conference"
    end

    def meetup?
      kind == "meetup"
    end

    def event_record
      @event_record ||= Event.find_by(slug: slug)
    end

    def start_date
      Date.parse(super)
    rescue TypeError, Date::Error
      super
    end

    def end_date
      Date.parse(super)
    rescue TypeError, Date::Error
      super
    end

    def published_date
      Date.parse(published_at)
    rescue TypeError, Date::Error
      nil
    end

    def country
      return nil if location.blank?
      return nil if location.downcase == "online"
      return nil if location.downcase == "earth"
      return nil if location.downcase == "unknown"

      country_split = location.split(",").last&.strip

      return nil if country_split.blank?

      country = ISO3166::Country.search(country_split)
      return country if country.present?

      return ISO3166::Country.new("US") if ISO3166::Country.new("US").subdivisions.keys.include?(country_split)
      return ISO3166::Country.new("GB") if country_split == "UK"
      return ISO3166::Country.new("GB") if country_split == "Scotland"

      country = ISO3166::Country.find_country_by_iso_short_name(country_split)  if country.nil?
      country = ISO3166::Country.find_country_by_unofficial_names(country_split) if country.nil?

      country
    end

    def home_sort_date
      if published_date
        return published_date
      end

      if conference? && end_date.present?
        return end_date
      end

      if meetup? && event_record.present?
        return event_record.end_date
      end

      if conference? && start_date.present?
        return start_date
      end

      if event_record.present?
        return event_record.start_date
      end

      Time.at(0)
    end

    def home_updated_text
      if published_date
        return "Talks recordings were published #{time_ago_in_words(published_date)} ago."
      end

      if today?
        return "Takes place today."
      end

      if end_date.present? && end_date.past?
        return "Took place #{time_ago_in_words(end_date)} ago."
      end

      if event_record.present? && event_record.end_date.past?
        return "Took place #{time_ago_in_words(event_record.end_date)} ago."
      end

      if start_date.present? && start_date.future?
        return "Takes place in #{time_ago_in_words(start_date)}."
      end

      if event_record.present? && event_record.start_date.future?
        "Takes place in #{time_ago_in_words(event_record.start_date)}."
      end
    end
  end
end
