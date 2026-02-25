module Static
  class Topic < FrozenRecord::Base
    self.backend = Backends::ArrayBackend.new("topics.yml")
    self.base_path = Rails.root.join("data")

    SEARCH_INDEX_ON_IMPORT_DEFAULT = ENV.fetch("SEARCH_INDEX_ON_IMPORT", "true") == "true"

    def self.import_all!(index: SEARCH_INDEX_ON_IMPORT_DEFAULT)
      topics = ::Topic.create_from_list(all.map(&:name), status: :approved)
      topics.each { |topic| Search::Backend.index(topic) } if index
      topics
    end

    def name
      item
    end

    def import!(index: SEARCH_INDEX_ON_IMPORT_DEFAULT)
      slug = name.parameterize
      topic = ::Topic.find_by(slug: slug)&.primary_topic || ::Topic.find_or_create_by(name: name, status: :approved)
      Search::Backend.index(topic) if index
      topic
    end
  end
end
