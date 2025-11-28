module Static
  class EventSeries < FrozenRecord::Base
    self.backend = Backends::MultiFileBackend.new("*/series.yml")
    self.base_path = Rails.root.join("data")

    class << self
      def find_by_slug(slug)
        @slug_index ||= all.index_by(&:slug)
        @slug_index[slug]
      end
    end

    def slug
      @slug ||= begin
        return attributes["slug"] if attributes["slug"].present?

        File.basename(File.dirname(__file_path))
      end
    end
  end
end
