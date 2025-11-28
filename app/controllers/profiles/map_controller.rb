class Profiles::MapController < ApplicationController
  include ProfileData

  def index
    @events = @user.participated_events.includes(:series)
    @countries_with_events = @events.group_by(&:country_code)
      .map { |code, events| [ISO3166::Country.new(code), events] }
      .reject { |country, _| country.nil? }
      .sort_by { |country, _| country.translations["en"] }
  end
end
