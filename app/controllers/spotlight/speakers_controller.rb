class Spotlight::SpeakersController < ApplicationController
  disable_analytics
  skip_before_action :authenticate_user!

  def index
    @speakers = User.speakers.canonical
    @speakers = @speakers.ft_search(search_query).with_snippets.ranked if search_query
    @speakers_count = @speakers.count(:id)
    @speakers = @speakers.limit(5)
    respond_to do |format|
      format.turbo_stream
    end
  end

  private

  helper_method :search_query
  def search_query
    params[:s].presence
  end
end
