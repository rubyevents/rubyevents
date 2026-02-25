module Static
  class Speaker < FrozenRecord::Base
    self.backend = Backends::FileBackend.new("speakers.yml")
    self.base_path = Rails.root.join("data")

    SEARCH_INDEX_ON_IMPORT_DEFAULT = ENV.fetch("SEARCH_INDEX_ON_IMPORT", "true") == "true"

    def self.import_all!(index: SEARCH_INDEX_ON_IMPORT_DEFAULT)
      imported_users = []
      speakers = all.to_a

      puts "Importing #{speakers.count} speakers..."

      ::User.transaction do
        speakers.each do |speaker|
          user = speaker.import!(index: false)
          imported_users << user if user
        end
      end

      imported_users.each { |user| Search::Backend.index(user) } if imported_users.any? && index
    end

    def import!(index: SEARCH_INDEX_ON_IMPORT_DEFAULT)
      user = ::User.find_by_github_handle(github) ||
        ::User.find_by(slug: slug) ||
        ::User.find_by_name_or_alias(name) ||
        ::User.find_by(slug: name.parameterize) ||
        ::User.new

      user.name = name
      user.twitter = twitter if twitter.present?
      user.github_handle = github if github.present?
      user.website = website if website.present?
      user.bio = bio if bio.present?
      user.save!

      Array(aliases).each do |alias_data|
        next if alias_data.blank?

        alias_name = alias_data["name"]
        alias_slug = alias_data["slug"]

        raise "No name provided for alias: #{alias_data.inspect} and user: #{user.inspect}" if alias_name.blank?
        raise "No slug provided for alias: #{alias_data.inspect} and user: #{user.inspect}" if alias_slug.blank?

        ::Alias.find_or_create_by!(aliasable: user, name: alias_name, slug: alias_slug)
      end

      Search::Backend.index(user) if index

      user
    rescue ActiveRecord::RecordInvalid => e
      puts "Couldn't save: #{name} (#{github}), error: #{e.message}"
      nil
    end
  end
end
