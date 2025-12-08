module Static
  class Topic < FrozenRecord::Base
    self.backend = Backends::ArrayBackend.new("topics.yml")
    self.base_path = Rails.root.join("data")

    def self.import_all!
      ::Topic.create_from_list(all.map(&:name), status: :approved)
    end

    def name
      item
    end

    def import!
      slug = name.parameterize
      ::Topic.find_by(slug: slug)&.primary_topic || ::Topic.find_or_create_by(name: name, status: :approved)
    end
  end
end
