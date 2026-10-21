# frozen_string_literal: true

module Static
  class Speaker < Yerba::Record::Base
    self.path = "speakers.yml"
    self.base_path = Rails.root.join("data")

    schema SpeakerSchema

    add_index :name, include: "aliases[]"
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
        (name.present? && (all.find_by(name: name) || find_by_name_ignoring_case(name) || find_by_github_handle(name))) ||
        nil
    end

    def self.canonical_name(reference)
      find_by(name: reference.to_s)&.name || reference.to_s.strip
    end

    def self.find_by_name_ignoring_case(name)
      return nil if name.blank?

      all.cached(:speakers_by_downcased_name) {
        all.each_with_object({}) do |speaker, index|
          [speaker.name, *speaker.alias_names].compact.each do |identifier|
            index[identifier.strip.downcase] ||= speaker
          end
        end
      }[name.to_s.strip.downcase]
    end

    def self.find_by_github_handle(handle)
      return nil if handle.blank?

      all.cached(:speakers_by_github_handle) {
        all.each_with_object({}) do |speaker, index|
          speaker.all_github_handles.each { |github_handle| index[github_handle.downcase] ||= speaker }
        end
      }[handle.to_s.strip.downcase]
    end

    def self.add(name:, github: "", **attributes)
      name = name.to_s.strip
      github = github.to_s.strip
      slug = name.parameterize

      raise InvalidSpeakerError, "Speaker name cannot be blank" if name.blank?
      raise InvalidSpeakerError, "Speaker name '#{name}' cannot be turned into a slug. Use a romanized name, or the GitHub handle if there is none, as the name and add '#{name}' as an alias." if slug.empty?
      raise DuplicateSpeakerError, "Speaker '#{name}' already exists" if known_reference?(name)
      raise DuplicateSpeakerError, "A speaker with GitHub handle '#{github}' already exists" if github.present? && find_by_github_handle(github)

      all.build({"name" => name, "github" => github, "slug" => slug}.merge(clean_attributes(attributes.except(:slug, "slug"))))
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

    def alias_names
      Array(self["aliases"]).filter_map { |alias_name| alias_name.to_s.presence }
    end

    def redirect_slugs
      Array(self["slugs"]).filter_map { |slug| slug.to_s.presence }
    end

    def all_github_handles
      [github, *Array(self["github_handles"])].filter_map { |handle| handle.to_s.strip.presence }
    end

    def add_alias(name:)
      self["aliases"] = alias_names + [name] unless alias_names.include?(name)

      self
    end

    def add_slug(slug)
      self["slugs"] = redirect_slugs + [slug] unless slug.blank? || redirect_slugs.include?(slug)

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
      user = all_github_handles.lazy.filter_map { |handle| ::User.find_by_github_handle(handle) }.first ||
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

      alias_names.each do |alias_name|
        next if ::Alias.exists?(aliasable: user, name: alias_name)

        conflicting_alias = ::Alias.where(aliasable_type: "User", name: alias_name).where.not(aliasable_id: user.id).first

        if conflicting_alias
          puts "Alias conflict: #{name} alias '#{alias_name}' conflicts with alias on User #{conflicting_alias.aliasable_id}"
          next
        end

        ::Alias.create!(aliasable: user, name: alias_name)
      end

      redirect_slugs.each do |redirect_slug|
        next if redirect_slug.blank? || redirect_slug == user.slug
        next if ::Alias.where(aliasable: user).where(slug: redirect_slug).or(::Alias.where(aliasable: user, name: redirect_slug)).exists?

        conflicting_alias = ::Alias.where(slug: redirect_slug).or(::Alias.where(aliasable_type: "User", name: redirect_slug)).where.not(aliasable_type: "User", aliasable_id: user.id).first
        conflicting_user = ::User.where(slug: redirect_slug).where.not(id: user.id).first

        if conflicting_alias || conflicting_user
          puts "Slug conflict: #{name} redirect slug '#{redirect_slug}' is already used by #{conflicting_alias ? "alias on #{conflicting_alias.aliasable_type} #{conflicting_alias.aliasable_id}" : "user #{conflicting_user.name} (id:#{conflicting_user.id})"}"
          next
        end

        ::Alias.create!(aliasable: user, name: redirect_slug, slug: redirect_slug)
      end

      Search::Backend.index(user) if index && user_changed

      user_changed ? user : nil
    rescue ActiveRecord::RecordInvalid => e
      puts "Couldn't save: #{name} (#{github}), error: #{e.message}"
      nil
    end
  end
end
