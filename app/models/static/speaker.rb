# frozen_string_literal: true

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

      if slug.present? && user.slug != slug
        conflicting_user = ::User.find_by(slug: slug)
        if conflicting_user && conflicting_user.id != user.id
          puts "Slug conflict: #{name} (#{github}) wants slug '#{slug}' but it belongs to #{conflicting_user.name} (id:#{conflicting_user.id})"
        end
      end

      user.name = name
      user.slug = slug if slug.present? && !::User.where.not(id: user.id).exists?(slug: slug)
      user.github_handle = github if github.present?
      user.twitter = twitter if twitter.present?
      user.bsky = bluesky if bluesky.present?
      user.mastodon = mastodon if mastodon.present?
      user.linkedin = linkedin if linkedin.present?
      user.speakerdeck = speakerdeck if speakerdeck.present?
      user.website = website if website.present?

      user_changed = user.changed? || user.new_record?
      user.save! if user_changed

      Array(aliases).each do |alias_data|
        next if alias_data.blank?

        alias_name = alias_data["name"]
        alias_slug = alias_data["slug"]

        raise format("No name provided for alias: %s and user: %s", alias_data.inspect, user.inspect) if alias_name.blank?
        raise format("No slug provided for alias: %s and user: %s", alias_data.inspect, user.inspect) if alias_slug.blank?

        conflicting_alias = ::Alias.where(slug: alias_slug).where.not(aliasable_type: "User", aliasable_id: user.id).first
        conflicting_user = ::User.where(slug: alias_slug).where.not(id: user.id).first

        if conflicting_alias
          puts "Alias conflict: #{name} alias '#{alias_name}' (#{alias_slug}) conflicts with alias on #{conflicting_alias.aliasable_type} #{conflicting_alias.aliasable_id}"
          next
        end

        if conflicting_user
          puts "Alias conflict: #{name} alias '#{alias_name}' (#{alias_slug}) conflicts with user #{conflicting_user.name} (id:#{conflicting_user.id})"
          next
        end

        ::Alias.find_or_create_by!(aliasable: user, name: alias_name, slug: alias_slug)
      end

      Search::Backend.index(user) if index && user_changed

      user_changed ? user : nil
    rescue ActiveRecord::RecordInvalid => e
      puts "Couldn't save: #{name} (#{github}), error: #{e.message}"
      nil
    end
  end
end
