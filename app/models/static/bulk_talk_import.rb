# frozen_string_literal: true

module Static
  class BulkTalkImport
    def self.run!
      new.run!
    end

    def initialize
      @now = Time.current
      @event_id_by_slug = ::Event.pluck(:slug, :id).to_h
      @event_name_by_id = ::Event.pluck(:id, :name).to_h
    end

    def run!
      @entries = collect_entries
      return if @entries.empty?

      resolve_speakers
      @existing_talks = ::Talk.where(static_id: @entries.map { |entry| entry[:video].id }).index_by(&:static_id)

      rows, @slug_changes = build_rows
      ::Talk.upsert_all(rows, unique_by: :static_id)

      @talk_id_by_static = ::Talk.where(static_id: rows.map { |row| row[:static_id] }).pluck(:static_id, :id).to_h

      link_parents
      sync_user_talks
      create_renamed_aliases
      recompute_counters
    end

    private

    def collect_entries
      entries = []

      Static::Video.all.each do |video|
        event_slug = video.__file_path&.split("/")&.[](-2)
        event_id = @event_id_by_slug[event_slug]
        next unless event_id

        collect(video, event_id, nil, entries)
      end

      entries
    end

    def collect(video, event_id, parent_video, entries)
      return if video.title.blank?

      no_speakers = Array.wrap(video.speakers).none?
      no_talks = Array.wrap(video.talks).none?
      return if no_speakers && no_talks && !video.meta_talk?

      entries << {video: video, event_id: event_id, parent_video: parent_video}

      video.talks.each { |child| collect(child, event_id, video, entries) }
    end

    def resolve_speakers
      names = @entries.flat_map { |entry| Array.wrap(entry[:video].speakers) }
        .reject(&:blank?).map(&:strip).uniq

      @user_id_by_name = {}

      if names.any?
        users_by_name = {}
        ::User.where(name: names, marked_for_deletion: false).order(:id).each { |user| users_by_name[user.name] ||= user }

        alias_uid_by_name = ::Alias.where(aliasable_type: "User", name: names).pluck(:name, :aliasable_id).to_h

        users_by_slug = {}
        ::User.where(slug: names.map(&:parameterize), marked_for_deletion: false).order(:id).each { |user| users_by_slug[user.slug] ||= user }

        missing = []
        names.each do |name|
          uid = users_by_name[name]&.id || alias_uid_by_name[name] || users_by_slug[name.parameterize]&.id

          if uid
            @user_id_by_name[name] = uid
          else
            missing << name
          end
        end

        missing.each { |name| @user_id_by_name[name] = ::User.find_or_create_by(name: name).id }
      end

      @slug_by_user_id = ::User.where(id: @user_id_by_name.values.uniq).pluck(:id, :slug).to_h
    end

    def speaker_ids_for(video)
      Array.wrap(video.speakers).reject(&:blank?).map { |name| @user_id_by_name[name.strip] }.compact.uniq
    end

    def build_rows
      reserved = ::Talk.pluck(:slug).to_set
      reserved.merge(::Alias.where(aliasable_type: "Talk").pluck(:slug))

      rows = []
      slug_changes = []

      @entries.each do |entry|
        video = entry[:video]
        parent = entry[:parent_video]
        existing = @existing_talks[video.id]

        speaker_ids = speaker_ids_for(video)
        kind = Talk::Kind.from(title: video.title, static_kind: video.kind)

        current_slug = existing&.slug
        reserved.delete(current_slug) if current_slug

        language = normalize_language(video.language)

        candidates = Talk::Slug.candidates(
          static_slug: video.slug,
          title: video.title,
          event_name: @event_name_by_id[entry[:event_id]],
          language: language,
          date: date_for(video, parent),
          speaker_slugs: speaker_ids.map { |id| @slug_by_user_id[id] },
          raw_title: video.raw_title
        )

        slug = Talk::Slug.pick(candidates, used: reserved) || current_slug
        reserved.add(slug)

        if current_slug.present? && current_slug != slug
          slug_changes << {static_id: video.id, name: video.title, slug: current_slug}
        end

        rows << {
          static_id: video.id,
          event_id: entry[:event_id],
          title: video.title,
          original_title: video.original_title || "",
          description: video.description,
          date: date_for(video, parent),
          published_at: video.try(:published_at) || parent&.try(:published_at),
          announced_at: video.try(:announced_at) || parent&.try(:announced_at),
          thumbnail_xs: video["thumbnail_xs"] || "",
          thumbnail_sm: video["thumbnail_sm"] || "",
          thumbnail_md: video["thumbnail_md"] || "",
          thumbnail_lg: video["thumbnail_lg"] || "",
          thumbnail_xl: video["thumbnail_xl"] || "",
          language: language,
          slides_url: video.slides_url,
          additional_resources: video["additional_resources"] || [],
          video_id: video.video_id,
          video_provider: video.video_provider,
          external_player: video.external_player || false,
          external_player_url: video.external_player_url || "",
          meta_talk: video.meta_talk?,
          start_seconds: video.start_cue_in_seconds,
          end_seconds: video.end_cue_in_seconds,
          kind: kind,
          slug: slug,
          created_at: existing&.created_at || @now,
          updated_at: @now
        }
      end

      [rows, slug_changes]
    end

    def date_for(video, parent)
      video.try(:date) || parent&.try(:date)
    end

    def normalize_language(language)
      Language.find(language.presence || Language::DEFAULT)&.alpha2
    end

    def link_parents
      pairs = @entries.filter_map do |entry|
        next unless entry[:parent_video]

        child_id = @talk_id_by_static[entry[:video].id]
        parent_id = @talk_id_by_static[entry[:parent_video].id]
        next unless child_id && parent_id

        [child_id, parent_id]
      end

      pairs.group_by(&:last).each do |parent_id, group|
        ::Talk.where(id: group.map(&:first)).update_all(parent_talk_id: parent_id)
      end
    end

    def sync_user_talks
      desired = []

      @entries.each do |entry|
        talk_id = @talk_id_by_static[entry[:video].id]
        next unless talk_id

        speaker_ids_for(entry[:video]).each { |user_id| desired << [talk_id, user_id] }
      end

      desired_set = desired.to_set
      touched_talk_ids = @talk_id_by_static.values
      existing_set = ::UserTalk.where(talk_id: touched_talk_ids).pluck(:talk_id, :user_id).to_set

      to_insert = desired_set - existing_set
      to_delete = existing_set - desired_set

      if to_insert.any?
        ::UserTalk.upsert_all(
          to_insert.map { |talk_id, user_id| {talk_id: talk_id, user_id: user_id, created_at: @now, updated_at: @now} },
          unique_by: [:user_id, :talk_id]
        )
      end

      to_delete.group_by(&:first).each do |talk_id, group|
        ::UserTalk.where(talk_id: talk_id, user_id: group.map(&:last)).delete_all
      end

      @affected_user_ids = (desired + to_delete.to_a).map(&:last).uniq
    end

    def create_renamed_aliases
      @slug_changes.each do |change|
        talk_id = @talk_id_by_static[change[:static_id]]
        next unless talk_id

        ::Alias.find_or_create_by!(aliasable_type: "Talk", aliasable_id: talk_id, name: change[:name], slug: change[:slug])
      end
    end

    def recompute_counters
      ::Event.connection.execute(
        "UPDATE events SET talks_count = (SELECT COUNT(*) FROM talks WHERE talks.event_id = events.id)"
      )

      ::User.where(id: @affected_user_ids).find_each { |user| user.update_column(:talks_count, user.kept_talks.count) }
    end
  end
end
