class Spotlight::SpeakersController < ApplicationController
  LIMIT = 15

  disable_analytics
  skip_before_action :authenticate_user!

  def index
    if search_query.present? && typesense_enabled?
      pagy, @speakers = User.typesense_search_speakers(search_query, per_page: LIMIT)
      @total_count = pagy.count
    else
      @speakers = User.speakers.canonical
      @speakers = @speakers.ft_search(search_query).with_snippets.ranked if search_query
      @total_count = @speakers.count
      @speakers = @speakers.limit(LIMIT)
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

  def typesense_enabled?
    User.respond_to?(:typesense_search_speakers)
  end
end
