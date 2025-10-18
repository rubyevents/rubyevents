class SponsorsController < ApplicationController
  skip_before_action :authenticate_user!
  before_action :set_sponsor, only: %i[show]

  # GET /sponsors
  def index
    @sponsors = Sponsor.includes(:events).order(:name)
    @sponsors = @sponsors.where("lower(name) LIKE ?", "#{params[:letter].downcase}%") if params[:letter].present?
    @featured_sponsors = Sponsor.joins(:event_sponsors).group("sponsors.id").order("COUNT(event_sponsors.id) DESC").limit(25).includes(:events)
  end

  # GET /sponsors/1
  def show
    @back_path = sponsors_path
    @events = @sponsor.events.includes(:organisation, :talks).order(start_date: :desc)
    @events_by_year = @events.group_by { |event| event.start_date&.year || "Unknown" }

    @countries_with_events = @events.group_by(&:country_code)
      .map { |code, events| [ISO3166::Country.new(code), events] }
      .reject { |country, _| country.nil? }
      .sort_by { |country, _| country.translations["en"] }

    involvements = @sponsor.event_involvements.includes(:event).order(:position)
    @involvements_by_role = involvements.group_by(&:role)
    @involved_events = @sponsor.involved_events.includes(:organisation).distinct.order(start_date: :desc)

    @statistics = prepare_sponsor_statistics
  end

  private

  def prepare_sponsor_statistics
    event_sponsors = @sponsor.event_sponsors.includes(event: [:talks, :organisation])

    {
      total_events: @events.size,
      total_countries: @countries_with_events.size,
      total_continents: @countries_with_events.map { |country, _| country.continent }.uniq.size,
      total_organisations: @events.map(&:organisation).uniq.size,
      total_talks: @events.joins(:talks).size,
      years_active: @events_by_year.keys.reject { |y| y == "Unknown" }.sort,
      first_sponsorship: @events.minimum(:start_date),
      latest_sponsorship: @events.maximum(:start_date),
      sponsorship_tiers: event_sponsors.group(:tier).count.sort_by { |_, count| -count },
      events_by_organisation: @events.group_by(&:organisation).transform_values(&:count).sort_by { |_, count| -count }.first(5),
      badges_with_events: event_sponsors.includes(:event).map { |es| [es.badge, es.event] if es.badge.present? }.compact,
      events_by_size: @events.includes(:talks).group_by { |event| classify_event_size(event) }.transform_values(&:count)
    }
  end

  def classify_event_size(event)
    talk_count = event.talks.size

    if talk_count == 0
      if event.start_date && event.start_date > Date.today
        return "Upcoming Event"
      else
        return "Event Awaiting Content"
      end
    end

    case talk_count
    when 1..5
      "Community Gathering"
    when 6..20
      "Regional Conference"
    when 21..50
      "Major Conference"
    else
      "Flagship Event"
    end
  end

  def set_sponsor
    @sponsor = Sponsor.find_by(slug: params[:slug])

    redirect_to sponsors_path, status: :moved_permanently, notice: "Sponsor not found" if @sponsor.blank?
  end
end
