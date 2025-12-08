module Static
  class Speaker < FrozenRecord::Base
    self.backend = Backends::FileBackend.new("speakers.yml")
    self.base_path = Rails.root.join("data")

    def self.import_all!
      all.each(&:import!)
    end

    def import!
      user = ::User.find_by_github_handle(github) ||
        ::User.find_by(slug: slug) ||
        ::User.find_by_name_or_alias(name) ||
        ::User.new

      user.name = name
      user.twitter = twitter if twitter.present?
      user.github_handle = github if github.present?
      user.website = website if website.present?
      user.bio = bio if bio.present?
      user.save!

      user
    rescue ActiveRecord::RecordInvalid => e
      puts "Couldn't save: #{name} (#{github}), error: #{e.message}"
      nil
    end
  end
end
