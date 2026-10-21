# frozen_string_literal: true

module Static
  class EventAsset < Yerba::Record::FileRecord
    self.path = "app/assets/images/events/**/:name.webp"

    validate :expected_dimensions, :belongs_to_event, on: :lint

    def self.expected_dimensions_for(name)
      return ::Event::Assets::DIMENSIONS[name] if ::Event::Assets::DIMENSIONS.key?(name)
      return ::Event::Assets::DIMENSIONS["sticker"] if name.match?(/\Asticker(?:-[^.]+)?\z/)

      ::Event::Assets::DIMENSIONS["stamp"] if name.match?(/\Astamp(?:-[^.]+)?\z/)
    end

    def folders
      File.dirname(file_path.split("app/assets/images/events/").last).split("/") - ["."]
    end

    private

    def expected_dimensions
      expected = self.class.expected_dimensions_for(basename)
      return unless expected

      width, height = FastImage.size(file_path)
      return if width.to_i.zero? || height.to_i.zero? || (width == expected[:width] && height == expected[:height])

      errors.add(:base, "Asset dimensions are #{width}x#{height}, expected #{expected[:width]}x#{expected[:height]}")
    end

    def belongs_to_event
      series_slug, event_slug = folders
      return if folders == ["default"]
      return if series_exists?(series_slug) && (event_slug.nil? || event_slug == "default" || event_exists?(series_slug, event_slug))

      errors.add(:base, "Asset does not belong to any event, there is no matching folder in data/#{folders.join("/")}")
    end

    def series_exists?(series_slug)
      File.exist?(File.join(path_root.to_s, "data", series_slug.to_s, "series.yml"))
    end

    def event_exists?(series_slug, event_slug)
      File.exist?(File.join(path_root.to_s, "data", series_slug.to_s, event_slug.to_s, "event.yml"))
    end
  end
end
