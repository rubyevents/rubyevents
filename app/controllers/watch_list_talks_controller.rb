class WatchListTalksController < ApplicationController
  include ActionView::RecordIdentifier

  before_action :authenticate_user!
  before_action :set_watch_list

  def create
    @talk = Talk.find(params[:talk_id])
    @watch_list.talks << @talk

    respond_to do |format|
      format.html { redirect_back fallback_location: @watch_list }
      format.turbo_stream
    end
  end

  def destroy
    @talk = @watch_list.talks.find(params[:id])
    WatchListTalk.find_by(talk_id: @talk.id, watch_list_id: @watch_list.id).destroy

    respond_to do |format|
      format.html { redirect_back fallback_location: @watch_list }
      format.turbo_stream
    end
  end

  private

  def set_watch_list
    @watch_list = Current.user.watch_lists.find(params[:watch_list_id])
  end
end
