module Static
  class Speaker < FrozenRecord::Base
    self.backend = Backends::FileBackend.new("speakers.yml")
    self.base_path = Rails.root.join("data")

    def self.import_all!
      speakers = all.to_a

      github_handles = speakers.map(&:github).compact.reject(&:blank?).map(&:downcase)
      users_by_github = ::User.where("lower(github_handle) IN (?)", github_handles).index_by { |u| u.github_handle&.downcase }

      slugs = speakers.map(&:slug).compact.reject(&:blank?)
      users_by_slug = ::User.where(slug: slugs).index_by(&:slug)

      names = speakers.map(&:name).compact.reject(&:blank?)
      users_by_name = ::User.where(name: names, marked_for_deletion: false).index_by(&:name)

      aliases_by_name = Alias.where(aliasable_type: "User", name: names).includes(:aliasable).index_by(&:name)

      existing_slugs = Set.new(::User.pluck(:slug).compact)
      existing_github_handles = Set.new(::User.where.not(github_handle: [nil, ""]).pluck(:github_handle).map(&:downcase))

      imported_user_ids = []

      ::User.skip_callback(:commit, :after, :reindex)

      begin
        ::User.transaction do
          speakers.each do |speaker|
            user = users_by_github[speaker.github&.downcase] ||
              users_by_slug[speaker.slug] ||
              users_by_name[speaker.name] ||
              aliases_by_name[speaker.name]&.aliasable

            if user
              attrs = {name: speaker.name, updated_at: Time.current}
              attrs[:twitter] = speaker.twitter if speaker.twitter.present?
              attrs[:github_handle] = speaker.github if speaker.github.present?
              attrs[:website] = speaker.website if speaker.website.present?
              attrs[:bio] = speaker.bio if speaker.bio.present?
              user.update_columns(attrs)
            else
              base_slug = speaker.slug.presence ||
                speaker.github&.downcase ||
                I18n.transliterate(speaker.name.downcase).parameterize

              slug = base_slug
              slug = "#{base_slug}-#{SecureRandom.hex(4)}" if existing_slugs.include?(slug)
              existing_slugs.add(slug)

              if speaker.github.present?
                existing_github_handles.add(speaker.github.downcase)
              end

              user = ::User.new(
                name: speaker.name,
                slug: slug,
                twitter: speaker.twitter.presence,
                github_handle: speaker.github.presence,
                website: speaker.website.presence,
                bio: speaker.bio.presence
              )

              user.save(validate: false)
            end

            imported_user_ids << user.id
          rescue => e
            puts "Couldn't save: #{speaker.name} (#{speaker.github}), error: #{e.message}"
          end
        end
      ensure
        ::User.set_callback(:commit, :after, :reindex)
      end

      ::User.where(id: imported_user_ids).find_each(&:reindex) if imported_user_ids.any?
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
