module Static
  class Event < FrozenRecord::Base
    include ActionView::Helpers::DateHelper

    self.backend = Backends::MultiFileBackend.new("**/**/event.yml")
    self.base_path = Rails.root.join("data")

    class << self
      def find_by_slug(slug)
        @slug_index ||= all.index_by(&:slug)
        @slug_index[slug]
      end

      def import_all!
        all.each(&:import!)
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

    def retreat?
      kind == "retreat"
    end

    def hackathon?
      kind == "hackathon"
    end

    def slug
      @slug ||= begin
        return attributes["slug"] if attributes["slug"].present?

        File.basename(File.dirname(__file_path))
      end
    end

    def event_record
      @event_record ||= ::Event.find_by(slug: slug) || import!
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

      Country.find(location.to_s.split(",").last&.strip)
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

    def static_series
      @static_series ||= Static::EventSeries.find_by_slug(series_slug)
    end

    def import!
      event = ::Event.find_or_create_by(slug: slug)

      event.update!(
        name: title,
        date: attributes["date"] || published_at,
        date_precision: date_precision || "day",
        series: static_series.event_series_record,
        website: website,
        country_code: country&.alpha2,
        start_date: start_date,
        end_date: end_date,
        kind: kind
      )

      event.sync_aliases_from_list(aliases) if aliases.present?

      puts event.slug unless Rails.env.test?

      import_cfps!(event)
      import_videos!(event)
      import_sponsors!(event)
      import_involvements!(event)

      event
    end

    def import_cfps!(event)
      cfp_file_path = Rails.root.join("data", series_slug, slug, "cfp.yml")

      return unless File.exist?(cfp_file_path)

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

    def import_videos!(event)
      return unless event.videos_file?

      event.videos_file.each do |talk_data|
        talk = ::Talk.find_or_initialize_by(static_id: talk_data["id"])
        talk.update_from_yml_metadata!(event: event)

        child_talks = talk_data["talks"]

        next unless child_talks

        Array.wrap(child_talks).each do |child_talk_data|
          child_talk = ::Talk.find_or_initialize_by(static_id: child_talk_data["id"])
          child_talk.parent_talk = talk
          child_talk.update_from_yml_metadata!(event: event)
        end
      rescue ActiveRecord::RecordInvalid => e
        puts "Couldn't save: #{talk_data["title"]} (#{talk_data["id"]}), error: #{e.message}"
      end
    end

    def import_sponsors!(event)
      return unless event.sponsors_file.exist?

      require "public_suffix"

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

                s = ::Organization.find_by(domain: domain) if domain.present?
              rescue PublicSuffix::Error, URI::InvalidURIError
                # If parsing fails, continue with other matching methods
              end
            end

            s ||= ::Organization.find_by(name: sponsor["name"]) || ::Organization.find_by(slug: sponsor["slug"]&.downcase)
            s ||= ::Organization.find_or_initialize_by(name: sponsor["name"])

            s.update(
              website: sponsor["website"],
              description: sponsor["description"],
              domain: domain
            )

            s.add_logo_url(sponsor["logo_url"]) if sponsor["logo_url"].present?
            s.logo_url = sponsor["logo_url"] if sponsor["logo_url"].present? && s.logo_url.blank?

            s = ::Organization.find_by(slug: s.slug) || ::Organization.find_by(name: s.name) unless s.persisted?

            s.save!

            event.sponsors.find_or_create_by!(organization: s, event: event).update!(tier: tier["name"], badge: sponsor["badge"])
          end
        end
      end
    end

    def involvements_file_path
      Rails.root.join("data", series_slug, slug, "involvements.yml")
    end

    def involvements_file?
      involvements_file_path.exist?
    end

    def import_involvements!(event)
      return unless involvements_file?

      event.event_involvements.destroy_all

      involvements = YAML.load_file(involvements_file_path)

      involvements.each do |involvement_data|
        role = involvement_data["name"]

        Array.wrap(involvement_data["users"]).each_with_index do |user_name, index|
          next if user_name.blank?

          user = ::User.find_by_name_or_alias(user_name)

          unless user
            puts "Creating user: #{user_name}" unless Rails.env.test?
            user = ::User.create!(name: user_name)
          end

          involvement = ::EventInvolvement.find_or_initialize_by(
            event: event,
            involvementable: user,
            role: role
          )
          involvement.position = index
          involvement.save!
        end

        user_count = involvement_data["users"]&.compact&.size || 0

        Array.wrap(involvement_data["organisations"]).each_with_index do |org_name, index|
          next if org_name.blank?

          organization = ::Organization.find_by(name: org_name) || ::Organization.find_by(slug: org_name.parameterize)

          unless organization
            puts "Creating organization: #{org_name}" unless Rails.env.test?
            organization = ::Organization.create!(name: org_name)
          end

          involvement = ::EventInvolvement.find_or_initialize_by(
            event: event,
            involvementable: organization,
            role: role
          )
          involvement.position = user_count + index
          involvement.save!
        end
      end
    end

    def series_slug
      @series_slug ||= __file_path.split("/")[-3]
    end

    def __file_path
      attributes["__file_path"]
    end
  end
end
