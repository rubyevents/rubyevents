class MergeUsersService
  PROFILE_FIELDS = %i[bio github_handle twitter bsky linkedin mastodon website speakerdeck pronouns pronouns_type location].freeze

  attr_reader :user_to_keep, :user_to_merge

  def initialize(user_to_keep:, user_to_merge:)
    @user_to_keep = user_to_keep
    @user_to_merge = user_to_merge
  end

  def call
    @merged_profile = PROFILE_FIELDS.to_h { |f| [f, user_to_merge.send(f)] }
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
      clear_unique_fields_from_merged_user
      merge_profile_fields
      succeeded = true
    end

    mark_merged_user_for_deletion if succeeded
  end

  private

  def create_alias
    return if user_to_merge.name.blank? || user_to_merge.slug.blank?
    user_to_keep.aliases.find_or_create_by!(name: user_to_merge.name, slug: user_to_merge.slug)
  end

  def transfer_talks
    user_to_merge.user_talks.each do |user_talk|
      dup = user_talk.dup
      dup.user = user_to_keep
      dup.save
    end
    user_to_merge.user_talks.destroy_all
  end

  def transfer_event_participations
    user_to_merge.event_participations.each do |participation|
      dup = participation.dup
      dup.user = user_to_keep
      dup.save
    end
    user_to_merge.event_participations.destroy_all
  end

  def transfer_event_involvements
    user_to_merge.event_involvements.each do |involvement|
      dup = involvement.dup
      dup.involvementable = user_to_keep
      dup.save
    end
    user_to_merge.event_involvements.destroy_all
  end

  def transfer_watched_talks
    user_to_merge.watched_talks.each do |watched_talk|
      next if user_to_keep.watched_talks.exists?(talk_id: watched_talk.talk_id)
      dup = watched_talk.dup
      dup.user = user_to_keep
      dup.save
    end
    user_to_merge.watched_talks.destroy_all
  end

  def transfer_bookmarks
    return unless user_to_merge.watch_lists.any?

    canonical_watch_list = user_to_keep.default_watch_list
    user_to_merge.watch_lists.each do |watch_list|
      watch_list.watch_list_talks.each do |wlt|
        canonical_watch_list.watch_list_talks.find_or_create_by(talk_id: wlt.talk_id)
      end
    end
    user_to_merge.watch_lists.destroy_all
  end

  def transfer_favorite_users
    user_to_merge.favorite_users.each do |fav|
      next if fav.favorite_user_id == user_to_keep.id
      user_to_keep.favorite_users.find_or_create_by(favorite_user_id: fav.favorite_user_id)
    end
    user_to_merge.favorite_users.destroy_all
  end

  def transfer_favorited_by
    user_to_merge.favorited_by.each do |fav|
      next if fav.user_id == user_to_keep.id
      user_to_keep.favorited_by.find_or_create_by(user_id: fav.user_id)
    end
    user_to_merge.favorited_by.destroy_all
  end

  def clear_unique_fields_from_merged_user
    user_to_merge.update_column(:github_handle, nil)
  end

  def merge_profile_fields
    updates = {}
    PROFILE_FIELDS.each do |field|
      next if user_to_keep.send(field).present?
      value = @merged_profile[field]
      updates[field] = value if value.present?
    end
    user_to_keep.update_columns(updates) if updates.any?
  end

  def mark_merged_user_for_deletion
    user_to_merge.delete
  end
end
