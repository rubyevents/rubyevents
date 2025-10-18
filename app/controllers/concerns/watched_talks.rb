module WatchedTalks
  extend ActiveSupport::Concern

  included do
    helper_method :user_watched_talks
  end

  private

  def user_watched_talks
    @user_watched_talks ||= Current.user&.watched_talks || WatchedTalk.none
  end
end
