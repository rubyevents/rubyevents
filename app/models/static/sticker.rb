# frozen_string_literal: true

module Static
  class Sticker < Yerba::Record::FileRecord
    self.path = "app/assets/images/events/:series_id/:event_id/sticker*.webp"

    belongs_to :event
    has_one :series, through: :event

    def self.for_user(user, events: user.attended_events)
      events.flat_map(&:stickers)
    end

    def variant
      basename.sub(/\Asticker[_-]?/i, "").presence
    end

    def code
      "#{event_id}-#{basename}".upcase
    end

    def name
      label = ["Sticker", variant&.titleize].compact.join(" ")

      "#{event&.title.presence || event_id.titleize} (#{label})"
    end

    def image_path
      path.relative_path_from(Pathname.new(path_root.to_s).join("app/assets/images")).to_s
    end

    def asset_path
      ActionController::Base.helpers.asset_path(image_path)
    end
  end
end
