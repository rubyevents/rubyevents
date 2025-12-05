class Spotlight::TalksController < ApplicationController
  LIMIT = 10

  disable_analytics
  skip_before_action :authenticate_user!

  def index
    @talks = Talk.watchable.includes(:speakers, event: :series)
    @talks = @talks.ft_search(search_query) if search_query.present?
    @talks = @talks.limit(LIMIT)

    respond_to do |format|
      format.turbo_stream
    end
  end

  private

  helper_method :search_query
  def search_query
    params[:s]
  end
end
