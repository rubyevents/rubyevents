class User::Merger < ActiveRecord::AssociatedObject
  PROFILE_FIELDS = %i[bio github_handle twitter bsky linkedin mastodon website speakerdeck pronouns pronouns_type location].freeze

  extension do
    def merge_with!(other_user)
      merger.merge!(other_user)
    end
  end

  def merge!(other_user)
    @other_user = other_user
    @merged_profile = PROFILE_FIELDS.to_h { |f| [f, other_user.send(f)] }
    succeeded = false

    ActiveRecord::Base.transaction do
      create_alias
      transfer_talks
      transfer_event_participations
      transfer_event_involvements
      transfer_watched_talks
      transfer_bookmarks
      transfer_favorite_users
      transfer_favorited_by
      transfer_connected_accounts
      clear_unique_fields_from_merged_user
      merge_profile_fields
      succeeded = true
    end

    delete_merged_user if succeeded
  end

  private

  def create_alias
    return if @other_user.name.blank? || @other_user.slug.blank?
    user.aliases.find_or_create_by!(name: @other_user.name, slug: @other_user.slug)

    @other_user.aliases.each do |existing_alias|
      if user.aliases.exists?(slug: existing_alias.slug)
        existing_alias.destroy
      else
        existing_alias.update!(aliasable: user)
      end
    end
  end

  def transfer_talks
    @other_user.user_talks.each do |user_talk|
      if user.user_talks.exists?(talk_id: user_talk.talk_id)
        user_talk.destroy
      else
        user_talk.update!(user: user)
      end
    end
  end

  def transfer_event_participations
    @other_user.event_participations.each do |participation|
      if user.event_participations.exists?(event_id: participation.event_id, attended_as: participation.attended_as)
        participation.destroy
      else
        participation.update!(user: user)
      end
    end
  end

  def transfer_event_involvements
    @other_user.event_involvements.each do |involvement|
      if user.event_involvements.exists?(event_id: involvement.event_id, role: involvement.role)
        involvement.destroy
      else
        involvement.update!(involvementable: user)
      end
    end
  end

  def transfer_watched_talks
    @other_user.watched_talks.each do |watched_talk|
      if user.watched_talks.exists?(talk_id: watched_talk.talk_id)
        watched_talk.destroy
      else
        watched_talk.update!(user: user)
      end
    end
  end

  def transfer_bookmarks
    return unless @other_user.watch_lists.any?

    canonical_watch_list = user.default_watch_list

    @other_user.watch_lists.each do |watch_list|
      watch_list.watch_list_talks.each do |watch_list_talk|
        if canonical_watch_list.watch_list_talks.exists?(talk_id: watch_list_talk.talk_id)
          watch_list_talk.destroy
        else
          watch_list_talk.update!(watch_list: canonical_watch_list)
        end
      end

      watch_list.reload.destroy
    end
  end

  def transfer_favorite_users
    @other_user.favorite_users.each do |fav|
      if fav.favorite_user_id == user.id || user.favorite_users.exists?(favorite_user_id: fav.favorite_user_id)
        fav.destroy
      else
        fav.update!(user: user)
      end
    end
  end

  def transfer_favorited_by
    @other_user.favorited_by.each do |fav|
      if fav.user_id == user.id || user.favorited_by.exists?(user_id: fav.user_id)
        fav.destroy
      else
        fav.update!(favorite_user: user)
      end
    end
  end

  def transfer_connected_accounts
    @other_user.connected_accounts.each do |account|
      if user.connected_accounts.exists?(provider: account.provider, username: account.username)
        account.destroy
      else
        account.update!(user: user)
      end
    end
  end

  def clear_unique_fields_from_merged_user
    @other_user.update_column(:github_handle, nil)
  end

  def merge_profile_fields
    updates = {}

    PROFILE_FIELDS.each do |field|
      next if user.send(field).present?
      value = @merged_profile[field]
      updates[field] = value if value.present?
    end

    user.update_columns(updates) if updates.any?
  end

  def delete_merged_user
    @other_user.delete
  end
end
