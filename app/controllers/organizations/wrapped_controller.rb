class Organizations::WrappedController < ApplicationController
  skip_before_action :authenticate_user!

  YEAR = 2025

  before_action :set_organization

  def index
    @year = YEAR
    year_range = Date.new(@year, 1, 1)..Date.new(@year, 12, 31)

    @sponsored_events = @organization.events
      .where(start_date: year_range)
      .includes(:series)
      .order(start_date: :asc)

    @total_events_sponsored = @sponsored_events.count

    @talks_at_sponsored_events = Talk
      .joins(:event)
      .where(events: {id: @sponsored_events.pluck(:id)})
      .count

    @speakers_at_sponsored_events = User
      .joins(:talks)
      .where(talks: {event_id: @sponsored_events.pluck(:id)})
      .distinct
      .count

    @countries_sponsored = @sponsored_events
      .map(&:country)
      .compact
      .uniq

    @sponsor_tiers = Sponsor
      .where(organization: @organization)
      .joins(:event)
      .where(events: {start_date: year_range})
      .group(:tier)
      .count
      .sort_by { |_, count| -count }

    @involved_events = @organization.involved_events
      .where(start_date: year_range)
      .includes(:series)
      .order(start_date: :asc)

    @involvements = @organization.event_involvements
      .joins(:event)
      .where(events: {start_date: year_range})
      .includes(:event)

    @involvements_by_role = @involvements.group_by(&:role)

    @share_url = organization_wrapped_index_url(organization_slug: @organization.slug)

    first_year = @organization.events.minimum(:start_date)&.year
    @years_supporting = first_year ? (@year - first_year + 1) : 1

    set_wrapped_meta_tags
  end

  def og_image
    ensure_card_generated

    if @organization.wrapped_card_horizontal.attached?
      disposition = params[:download].present? ? "attachment" : "inline"
      redirect_to rails_blob_url(@organization.wrapped_card_horizontal, disposition: disposition), allow_other_host: true
    else
      head :internal_server_error
    end
  end

  private

  def set_organization
    @organization = Organization.find_by!(slug: params[:organization_slug])
  end

  def set_wrapped_meta_tags
    description = "See #{@organization.name}'s #{@year} Ruby Events Wrapped!"
    title = "#{@organization.name}'s #{@year} Wrapped - RubyEvents.org"
    image_url = og_image_organization_wrapped_index_url(organization_slug: @organization.slug)

    set_meta_tags(
      title: title,
      description: description,
      og: {
        title: title,
        description: description,
        image: image_url,
        type: "website",
        url: @share_url
      },
      twitter: {
        title: title,
        description: description,
        image: image_url,
        card: "summary_large_image"
      }
    )
  end

  def ensure_card_generated
    return if @organization.wrapped_card_horizontal.attached?

    @year = YEAR
    year_range = Date.new(@year, 1, 1)..Date.new(@year, 12, 31)

    @sponsored_events = @organization.events.where(start_date: year_range)
    @total_events_sponsored = @sponsored_events.count
    @countries_sponsored = @sponsored_events.map(&:country).compact.uniq

    @talks_at_sponsored_events = Talk
      .joins(:event)
      .where(events: {id: @sponsored_events.pluck(:id)})
      .count

    @speakers_at_sponsored_events = User
      .joins(:talks)
      .where(talks: {event_id: @sponsored_events.pluck(:id)})
      .distinct
      .count

    @share_url = organization_wrapped_index_url(organization_slug: @organization.slug)

    first_year = @organization.events.minimum(:start_date)&.year
    @years_supporting = first_year ? (@year - first_year + 1) : 1

    generator = Organization::WrappedScreenshotGenerator.new(@organization)
    generator.save_to_storage(wrapped_locals)
    @organization.reload
  end

  def wrapped_locals
    {
      organization: @organization,
      year: @year,
      sponsored_events: @sponsored_events,
      total_events_sponsored: @total_events_sponsored,
      countries_sponsored: @countries_sponsored,
      talks_at_sponsored_events: @talks_at_sponsored_events,
      speakers_at_sponsored_events: @speakers_at_sponsored_events,
      share_url: @share_url,
      years_supporting: @years_supporting
    }
  end
end
