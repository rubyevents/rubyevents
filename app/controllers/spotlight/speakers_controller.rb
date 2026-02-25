class Spotlight::SpeakersController < ApplicationController
  include SpotlightSearch

  LIMIT = 15

  disable_analytics
  skip_before_action :authenticate_user!

  def index
    if search_query.present?
      @speakers, @total_count = search_backend_class.search_speakers(search_query, limit: LIMIT)
    else
      @speakers = User.speakers.canonical
        .where.not("LOWER(name) IN (?)", %w[todo tbd tba])
        .order(talks_count: :desc)
        .limit(LIMIT)
      @total_count = nil
    end

    respond_to do |format|
      format.turbo_stream
    end
  end

  private

  helper_method :search_query
  def search_query
    params[:s].presence
  end

  helper_method :total_count
  attr_reader :total_count
end
