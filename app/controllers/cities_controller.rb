class CitiesController < ApplicationController
  skip_before_action :authenticate_user!, only: %i[index show show_by_country show_with_state]

  def index
    @cities = City.all
  end

  def show
    @city = FeaturedCity.find_by(slug: params[:slug])

    if @city.blank?
      redirect_to cities_path
      return
    end

    load_city_data
  end

  def show_by_country
    @country = Country.find_by(country_code: params[:alpha2].upcase)

    if @country.blank?
      redirect_to countries_path
      return
    end

    @city_slug = params[:city]
    @city_name = @city_slug.tr("-", " ").titleize

    @city = FeaturedCity.find_by(slug: @city_slug)
    @city ||= FeaturedCity.find_for(city: @city_name, country_code: @country.alpha2)

    if @city.present?
      redirect_to city_path(@city.slug), status: :moved_permanently
      return
    end

    @city = City.new(
      name: @city_name,
      slug: @city_slug,
      country_code: @country.alpha2,
      state_code: nil
    )

    if @city.events.empty? && @city.users.empty?
      redirect_to country_path(@country)
      return
    end

    set_city_coordinates

    load_city_data
    render :show
  end

  def show_with_state
    @country = Country.find_by(country_code: params[:alpha2].upcase)

    if @country.blank?
      redirect_to countries_path
      return
    end

    @state = State.find(country: @country, term: params[:state])

    if @state.blank?
      redirect_to country_path(@country)
      return
    end

    @city_slug = params[:city]
    @city_name = @city_slug.tr("-", " ").titleize

    @city = FeaturedCity.find_by(slug: @city_slug)

    @city ||= FeaturedCity.find_for(
      city: @city_name,
      country_code: @country.alpha2,
      state_code: @state.code
    )

    if @city.present?
      redirect_to city_path(@city.slug), status: :moved_permanently
      return
    end

    @city = City.new(
      name: @city_name,
      slug: @city_slug,
      country_code: @country.alpha2,
      state_code: @state.code
    )

    if @city.events.empty? && @city.users.empty?
      redirect_to state_path(alpha2: @country.code, slug: @state.slug)
      return
    end

    set_city_coordinates

    load_city_data
    render :show
  end

  private

  def load_city_data
    @events = @city.events.includes(:series).order(start_date: :desc)
    @users = @city.users.geocoded.order(talks_count: :desc)
    @location = @city.location_string

    if @city.geocoded?
      @nearby_users = @city.nearby_users(exclude_ids: @users.pluck(:id))
      @nearby_events = @city.nearby_events if @events.empty?
    end
  end

  def set_city_coordinates
    @city = @city.with_coordinates
  end
end
