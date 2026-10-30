class TranscriptSearchesController < ApplicationController
  include SpotlightSearch

  PER_PAGE = 20

  skip_before_action :authenticate_user!

  def index
    @page = [params[:page].to_i, 1].max

    @groups, @total_talks, @total_moments = if search_query.present?
      search_backend_class.search_transcript_passages(search_query, limit: PER_PAGE, page: @page)
    else
      [[], 0, 0]
    end

    @total_talks = @total_talks.to_i
    @total_moments = @total_moments.to_i
    @pagy = Pagy.new(count: @total_talks, page: @page, limit: PER_PAGE) if @total_talks.positive?
  end

  private

  helper_method :search_query
  def search_query
    params[:q].to_s.presence
  end
end
