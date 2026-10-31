# frozen_string_literal: true

module Static
  class SeriesSticker < Yerba::Record::FileRecord
    self.path = "app/assets/images/events/:event_series_id/sticker*.webp"

    belongs_to :event_series

    def variant
      basename.sub(/\Asticker[_-]?/i, "").presence
    end

    def url_path
      Router.series_path(event_series_id)
    end

    def code
      "#{event_series_id}-#{basename}".upcase
    end

    def name
      label = ["Sticker", variant&.titleize].compact.join(" ")

      "#{event_series&.name.presence || event_series_id.titleize} (#{label})"
    end

    def image_path
      path.relative_path_from(Pathname.new(path_root.to_s).join("app/assets/images")).to_s
    end

    def asset_path
      Router.asset_path(image_path)
    end
  end
end
