# frozen_string_literal: true

module Static
  class BulkSpeakerImport
    SOCIAL_COLUMNS = %i[name slug github_handle twitter bsky mastodon linkedin speakerdeck website].freeze

    def self.run!(index: false)
      new.run!(index: index)
    end

    def run!(index: false)
      @speakers = Static::Speaker.all.to_a
      puts "Importing #{@speakers.size} speakers (bulk)..." unless Rails.env.test?

      preload
      assemble
      persist_users
      persist_aliases

      reindex if index
    end

    private

    def preload
      users = ::User.all.to_a

      @user_by_id = users.index_by(&:id)
      @user_by_github = {}
      @user_by_slug = {}
      @user_by_name = {}

      users.each do |user|
        @user_by_github[user.github_handle.downcase] = user if user.github_handle.present?
        @user_by_slug[user.slug] = user if user.slug.present?
        @user_by_name[user.name] ||= user unless user.marked_for_deletion?
      end

      @alias_user_id_by_name = ::Alias.where(aliasable_type: "User").pluck(:name, :aliasable_id).to_h
      @reserved_slugs = @user_by_slug.keys.to_set
    end

    def assemble
      @inserts = []
      @updates = []
      @resolved = [] # [{user:, speaker:, new_record:}]

      @speakers.each do |speaker|
        user = resolve(speaker)
        new_record = user.new_record?

        assign(user, speaker)
        assign_slug(user, speaker, new_record)
        index_user(user)

        if new_record
          @inserts << user
        elsif user.changed?
          @updates << user
        end

        @resolved << {user: user, speaker: speaker, new_record: new_record}
      end
    end

    def resolve(speaker)
      user = (speaker.github.present? ? @user_by_github[speaker.github.downcase] : nil)

      user ||= (speaker.slug.present? ? @user_by_slug[speaker.slug] : nil)
      user ||= @user_by_name[speaker.name] || @user_by_id[@alias_user_id_by_name[speaker.name]]
      user ||= @user_by_slug[speaker.name.parameterize]

      user || ::User.new
    end

    def assign(user, speaker)
      user.name = speaker.name
      user.slug = speaker.slug if speaker.slug.present? && !slug_taken_by_other?(speaker.slug, user)
      user.github_handle = speaker.github if speaker.github.present?
      user.twitter = speaker.twitter if speaker.twitter.present?
      user.bsky = speaker.bluesky if speaker.bluesky.present?
      user.mastodon = speaker.mastodon if speaker.mastodon.present?
      user.linkedin = speaker.linkedin if speaker.linkedin.present?
      user.speakerdeck = speaker.speakerdeck if speaker.speakerdeck.present?
      user.website = speaker.website if speaker.website.present?
    end

    def assign_slug(user, speaker, new_record)
      return unless new_record && user.slug.blank?

      base = I18n.transliterate(user.name.downcase).parameterize
      user.slug = @reserved_slugs.include?(base) ? "#{base}-#{SecureRandom.hex(4)}" : base
    end

    def slug_taken_by_other?(slug, user)
      other = @user_by_slug[slug]

      other && !other.equal?(user)
    end

    def index_user(user)
      @user_by_github[user.github_handle.downcase] = user if user.github_handle.present?
      @user_by_slug[user.slug] = user if user.slug.present?
      @user_by_name[user.name] ||= user
      @reserved_slugs << user.slug if user.slug.present?
    end

    def persist_users
      now = Time.current

      if @inserts.any?
        rows = @inserts.map do |user|
          user.attributes.except("id").merge("created_at" => now, "updated_at" => now)
        end

        ::User.insert_all(rows, unique_by: :slug)
      end

      if @updates.any?
        rows = @updates.map do |user|
          {id: user.id, updated_at: now}.merge(SOCIAL_COLUMNS.index_with { |column| user[column] })
        end

        ::User.upsert_all(rows, unique_by: :id, update_only: SOCIAL_COLUMNS + [:updated_at])
      end

      inserted_slugs = @inserts.map(&:slug)
      @id_by_slug = ::User.where(slug: inserted_slugs + @updates.map(&:slug)).pluck(:slug, :id).to_h
    end

    def user_id_for(entry)
      entry[:user].id || @id_by_slug[entry[:user].slug]
    end

    def persist_aliases
      existing_alias_slugs = ::Alias.pluck(:slug).to_set
      existing_user_slugs = ::User.where.not(slug: nil).pluck(:slug).to_set
      seen = ::Alias.where(aliasable_type: "User").pluck(:aliasable_id, :name).to_set

      rows = []

      @resolved.each do |entry|
        aliases = Array(entry[:speaker].aliases)
        next if aliases.empty?

        user_id = user_id_for(entry)
        next unless user_id

        aliases.each do |alias_data|
          next if alias_data.blank?

          name = alias_data["name"]
          slug = alias_data["slug"]

          next if name.blank? || slug.blank?
          next if seen.include?([user_id, name])
          next if existing_alias_slugs.include?(slug) || existing_user_slugs.include?(slug)

          rows << {aliasable_type: "User", aliasable_id: user_id, name: name, slug: slug, created_at: Time.current, updated_at: Time.current}
          seen << [user_id, name]
          existing_alias_slugs << slug
        end
      end

      ::Alias.insert_all(rows, unique_by: [:aliasable_type, :name]) if rows.any?
    end

    def reindex
      ids = (@inserts + @updates).map(&:slug)

      ::User.where(slug: ids).find_each { |user| Search::Backend.index(user) }
    end
  end
end
