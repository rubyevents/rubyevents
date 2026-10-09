class WatchListTalksController < ApplicationController
  before_action :authenticate_user!
  before_action :set_watch_list

  def create
    @talk = Talk.find(params[:talk_id])
    @watch_list.talks << @talk unless @watch_list.talk_ids.include?(@talk.id)
    respond_to_toggle
  end

  def destroy
    @watch_list.watch_list_talks.find_by(talk_id: params[:id])&.destroy
    respond_to_toggle
  end

  private

  def respond_to_toggle
    if request.format.turbo_stream?
      redirect_back fallback_location: @watch_list
    else
      head :no_content
    end
  end

  def set_watch_list
    @watch_list = Current.user.watch_lists.find(params[:watch_list_id])
  end
end
