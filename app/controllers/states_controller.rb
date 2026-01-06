class StatesController < ApplicationController
  skip_before_action :authenticate_user!, only: %i[index country_index show]

  def index
    @countries_with_states = State::SUPPORTED_COUNTRIES.map do |code|
      Country.find_by(country_code: code)
    end.compact
  end

  def country_index
    @country = Country.find_by(country_code: params[:alpha2].upcase)

    if @country.blank?
      redirect_to states_path
      return
    end

    @states = State.all(country: @country)
  end

  def show
    @country = Country.find_by(country_code: params[:alpha2].upcase)

    if @country.blank?
      redirect_to states_path
      return
    end

    @state = State.find(country: @country, term: params[:slug])

    if @state.blank?
      redirect_to country_states_path(alpha2: @country.code)
      return
    end

    @events = @state.events.includes(:series).order(start_date: :desc)

    @events_by_city = @events
      .select { |event| event.city.present? }
      .group_by(&:city)
      .sort_by { |city, _events| city }
      .to_h

    @users = @state.users.geocoded.order(talks_count: :desc)
  end
end
