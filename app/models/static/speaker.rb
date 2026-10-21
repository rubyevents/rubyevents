# frozen_string_literal: true

module Static
  class Speaker < Yerba::Record::Base
    self.path = "data/speakers.yml"

    schema do
      string :name, description: "Full name of the speaker", required: true
      string :slug, description: "URL-friendly slug for the speaker", required: true
      string :github, description: "GitHub username (not a URL)", required: true, pattern: "^([^/:\\s]+)?$"

      string :twitter, description: "Twitter/X handle (without @, not a URL)", required: false, pattern: "^([^/:\\s]+)?$"
      string :website, description: "Personal website URL", required: false
      string :mastodon, description: "Full Mastodon profile URL (e.g. https://ruby.social/@username)", required: false, pattern: "^(https?://[^/]+/@[^/\\s]+)?$"
      string :bluesky, description: "Bluesky handle (not a URL)", required: false, pattern: "^([^/:\\s]+)?$"
      string :linkedin, description: "LinkedIn username (the part after /in/, not a URL)", required: false, pattern: "^([^/:\\s]+)?$"
      string :speakerdeck, description: "Speakerdeck username (not a URL)", required: false, pattern: "^([^/:\\s]+)?$"

      array :aliases, description: "Alternative names for the speaker", required: false do
        object do
          string :name, required: true
          string :slug, required: true
        end
      end

      string :canonical_slug, description: "Slug of the canonical speaker profile (for deduplication)", required: false
    end

    add_index :name, include: "aliases[].name"
    add_index :slug
    add_index :github

    self.order_by = "name"

    extend Integrity

    SOCIAL_HANDLE_FIELDS = %w[github twitter mastodon bluesky linkedin speakerdeck].freeze
    SEARCH_INDEX_ON_IMPORT_DEFAULT = ENV.fetch("SEARCH_INDEX_ON_IMPORT", "true") == "true"

    class InvalidSpeakerError < StandardError; end
    class DuplicateSpeakerError < StandardError; end

    def self.find_by(**criteria)
      if criteria.any? && criteria.keys.all? { |key| key.in?(%i[name slug github]) }
        return find_speaker(**criteria)
      end

      super
    end

    def self.find_or_create_by(name:)
      find_by(name: name) || create(name: name)
    end

    def self.find_speaker(name: nil, slug: nil, github: nil)
      name = name&.strip
      slug = slug&.strip
      github = github&.strip

      (slug.present? && all.find_by(slug: slug)) ||
        (github.present? && all.find_by(github: github)) ||
        (name.present? && (all.find_by(name: name) || find_by_github_handle(name))) ||
        nil
    end

    def self.find_by_github_handle(handle)
      return nil if handle.blank?

      all.cached(:speakers_by_github_handle) {
        all.each_with_object({}) { |speaker, index| index[speaker.github.downcase] = speaker if speaker.github.present? }
      }[handle.to_s.strip.downcase]
    end

    def self.add(name:, github: "", slug: nil, **attributes)
      name = name.to_s.strip
      github = github.to_s.strip
      slug = slug&.strip

      raise InvalidSpeakerError, "Speaker name cannot be blank" if name.blank?
      raise DuplicateSpeakerError, "Speaker '#{name}' already exists" if known_reference?(name)
      raise DuplicateSpeakerError, "A speaker with GitHub handle '#{github}' already exists" if github.present? && all.find_by(github: github)

      all.build({"name" => name, "github" => github, "slug" => slug || name.parameterize}.merge(clean_attributes(attributes)))
    end

    def self.upsert(name:, github: "", **attributes)
      raise InvalidSpeakerError, "Speaker name cannot be blank" if name.blank?

      speaker = find_speaker(name: name, github: github)
      return add(name: name, github: github, **attributes) unless speaker

      speaker.assign(github: github, **attributes)
    end

    def self.create(name:, **attributes)
      speakers = all

      add(name: name, **attributes)
      speakers.save!

      find_by(name: name)
    ensure
      unload!
    end

    def self.save!
      all.save!
    end

    def self.changed?
      all.changed?
    end

    def self.clean_attributes(attributes)
      attributes
        .transform_keys(&:to_s)
        .reject { |_, value| value.blank? }
        .transform_values { |value| value.is_a?(String) ? value.strip : value }
    end

    def assign(**attributes)
      self.class.clean_attributes(attributes).each { |key, value| self[key] = value }

      self
    end

    def add_alias(name:, slug: nil)
      self["aliases"] = Array(self["aliases"]) + [{"name" => name, "slug" => (slug || name.parameterize).to_s}]

      self
    end

    def social_handle?
      SOCIAL_HANDLE_FIELDS.any? { |field| self[field].to_s.strip.present? }
    end

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
