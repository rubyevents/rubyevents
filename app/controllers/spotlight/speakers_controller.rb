class Spotlight::SpeakersController < ApplicationController
  include TypesenseSearch

  LIMIT = 15

  disable_analytics
  skip_before_action :authenticate_user!

  def index
    if search_query.present? && typesense_available?
      pagy, @speakers = User.typesense_search_speakers(search_query, per_page: LIMIT)
      @total_count = pagy.count
    elsif search_query.present?
      @speakers = User.speakers.canonical
      @speakers = @speakers.ft_search(search_query).with_snippets.ranked
      @total_count = @speakers.except(:select).count
      @speakers = @speakers.limit(LIMIT)
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
