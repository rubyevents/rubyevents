# frozen_string_literal: true

class Continents::BaseController < ApplicationController
  include EventMapMarkers

  skip_before_action :authenticate_user!

  before_action :set_continent

  private

  def set_continent
    @continent = Continent.find(params[:continent_continent])

    redirect_to(continents_path) and return unless @continent.present?
  end

  def continent_events
    @continent_events ||= @continent.events.includes(:series).order(start_date: :desc)
  end

  def upcoming_events
    @upcoming_events ||= continent_events.upcoming.reorder(start_date: :asc)
  end

  def past_events
    @past_events ||= continent_events.past.reorder(end_date: :desc)
  end
end
