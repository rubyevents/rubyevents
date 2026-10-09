class Spotlight::TranscriptsController < ApplicationController
  include SpotlightSearch

  LIMIT = 5

  disable_analytics
  skip_before_action :authenticate_user!

  def index
    @groups, @total_count = if search_query.present?
      search_backend_class.search_transcript_passages(search_query, limit: LIMIT)
    else
      [[], nil]
    end

    respond_to do |format|
      format.turbo_stream do
        response.headers["X-Search-Backend"] = search_backend.to_s if Rails.env.development? && search_backend
      end
    end
  end

  private

  helper_method :search_query
  def search_query
    params[:s]
  end

  helper_method :total_count
  attr_reader :total_count
end
