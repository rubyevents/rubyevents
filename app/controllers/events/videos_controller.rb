class Events::VideosController < ApplicationController
  include WatchedTalks

  skip_before_action :authenticate_user!, only: %i[index]
  before_action :set_event, only: %i[index]
  before_action :set_user_favorites, only: %i[index]

  def index
    @talks = @event.talks_in_running_order.watchable.includes(:speakers, :parent_talk, child_talks: :speakers).reverse
    @active_talk = Talk.find_by(slug: params[:active_talk])
  end

  private

  def set_event
    @event = Event.includes(:series, talks: :speakers).find_by(slug: params[:event_slug])
    set_meta_tags(@event)
  end

  def set_user_favorites
    return unless Current.user

    @user_favorite_talks_ids = Current.user.default_watch_list.talks.ids
  end
end
