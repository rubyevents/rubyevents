class Events::TalksController < ApplicationController
  include WatchedTalks

  skip_before_action :authenticate_user!, only: %i[index]
  before_action :set_event, only: %i[index]
  before_action :set_user_favorites, only: %i[index]

  def index
    @talks = @event.talks_in_running_order.where(meta_talk: false).includes(:speakers, :parent_talk, child_talks: :speakers).order(date: :desc)
  end

  private

  def set_event
    @event = Event.includes(:series, talks: :speakers).find_by(slug: params[:event_slug])
    return redirect_to(root_path, status: :moved_permanently) unless @event

    set_meta_tags(@event)
  end

  def set_user_favorites
    return unless Current.user

    @user_favorite_talks_ids = Current.user.default_watch_list.talks.ids
  end
end
