class Countries::BaseController < ApplicationController
  skip_before_action :authenticate_user!

  before_action :set_country

  private

  def set_country
    @country = Country.find(params[:country_country])
    redirect_to(countries_path) and return unless @country.present?
  end

  def country_events
    @country_events ||= @country.events.includes(:series).sort_by { |e| event_sort_date(e) }.reverse
  end

  def event_sort_date(event)
    event.static_metadata&.home_sort_date || Time.at(0).to_date
  end
end
