class OrganizationsController < ApplicationController
  skip_before_action :authenticate_user!
  before_action :set_organization, only: %i[show]

  # GET /organizations
  def index
    @organizations = Organization.includes(:events).order(:name)
    @organizations = @organizations.where("lower(name) LIKE ?", "#{params[:letter].downcase}%") if params[:letter].present?
    @featured_organizations = Organization.joins(:sponsors).group("organizations.id").order("COUNT(sponsors.id) DESC").limit(25).includes(:events)
  end

  # GET /organizations/1
  def show
    @back_path = organizations_path
    @events = @organization.events.includes(:series, :talks).order(start_date: :desc)
    @events_by_year = @events.group_by { |event| event.start_date&.year || "Unknown" }

    @countries_with_events = @events.grouped_by_country

    involvements = @organization.event_involvements.includes(:event).order(:position)
    @involvements_by_role = involvements.group_by(&:role)
    @involved_events = @organization.involved_events.includes(:series).distinct.order(start_date: :desc)

    @statistics = prepare_organization_statistics
  end

  private

  def prepare_organization_statistics
    sponsors = @organization.sponsors.includes(event: [:talks, :series])

    {
      total_events: @events.size,
      total_countries: @countries_with_events.size,
      total_continents: @countries_with_events.map { |country, _| country.continent_name }.uniq.size,
      total_series: @events.map(&:series).uniq.size,
      total_talks: @events.joins(:talks).size,
      years_active: @events_by_year.keys.reject { |y| y == "Unknown" }.sort,
      first_sponsorship: @events.minimum(:start_date),
      latest_sponsorship: @events.maximum(:start_date),
      sponsorship_tiers: sponsors.group(:tier).count.sort_by { |_, count| -count },
      events_by_series: @events.group_by(&:series).transform_values(&:count).sort_by { |_, count| -count }.first(5),
      badges_with_events: sponsors.includes(:event).map { |s| [s.badge, s.event] if s.badge.present? }.compact,
      events_by_size: @events.includes(:talks).group_by { |event| classify_event_size(event) }.transform_values(&:count)
    }
  end

  def classify_event_size(event)
    return "Retreat" if event.retreat?
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

  def set_organization
    @organization = Organization.find_by(slug: params[:slug])

    redirect_to organizations_path, status: :moved_permanently, notice: "Organization not found" if @organization.blank?
  end
end
