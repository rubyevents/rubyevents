class PageController < ApplicationController
  skip_before_action :authenticate_user!

  def home
    home_page_cached_data = Rails.cache.fetch("home_page_content", expires_in: 1.hour) do
      latest_talks = Talk.watchable.with_speakers.order(date: :desc).limit(10)
      {
        talks_count: Talk.count,
        speakers_count: Speaker.count,
        latest_talk_ids: latest_talks.pluck(:id),
        upcoming_talk_ids: Talk.with_speakers.where(date: Date.today..).order(date: :asc).limit(15).pluck(:id),
        latest_event_ids: Event.order(date: :desc).limit(10).pluck(:id).sample(4),
        featured_speaker_ids: Speaker.with_github
          .joins(:talks)
          .where(talks: {date: 12.months.ago..})
          .pluck(:id)
      }
    end

    @talks_count = home_page_cached_data[:talks_count]
    @speakers_count = home_page_cached_data[:speakers_count]
    @latest_talks = Talk.includes(event: :organisation).where(id: home_page_cached_data[:latest_talk_ids])
    @upcoming_talks = Talk.includes(event: :organisation).where(id: home_page_cached_data[:upcoming_talk_ids])
    @latest_events = Event.includes(:organisation).where(id: home_page_cached_data[:latest_event_ids])
    @featured_speakers = Speaker.where(id: home_page_cached_data[:featured_speaker_ids]).sample(10)
    @featured_sponsors = Sponsor.joins(:event_sponsors).group("sponsors.id").order("COUNT(event_sponsors.id) DESC").limit(25)

    # Add featured events logic
    playlist_slugs = Static::Playlist.where.not(featured_background: nil)
      .select(&:featured?)
      .sort_by(&:home_sort_date)
      .reverse
      .take(25)
      .map(&:slug)

    @featured_events = Event.distinct
      .includes(:organisation)
      .where(slug: playlist_slugs)
      # .with_watchable_talks
      .in_order_of(:slug, playlist_slugs)

    respond_to do |format|
      format.html
      format.json {
        render json: {
          featured: @featured_events.map { |event| event.to_mobile_json(request) },
          talks: [
            {
              name: "Latest Recordings",
              items: @latest_talks.map { |talk| talk.to_mobile_json(request) },
              url: talks_url
            },
            {
              name: "Upcoming Talks",
              items: @upcoming_talks.map { |talk| talk.to_mobile_json(request) },
              url: talks_url
            }
          ],
          speakers: [
            {
              name: "Active Speakers",
              items: @featured_speakers.map { |speaker| speaker.to_mobile_json(request) },
              url: speakers_url
            }
          ],
          events: [
            {
              name: "Upcoming Events",
              items: Event.upcoming.limit(10).map { |event| event.to_mobile_json(request) },
              url: events_url
            },
            {
              name: "Recent Events",
              items: Event.past.limit(10).map { |event| event.to_mobile_json(request) },
              url: past_events_url
            }
          ]
        }
      }
    end
  end

  def featured
  end

  def components
  end

  def uses
  end

  def privacy
  end

  def about
  end

  def stickers
    @events = Event.all.select(&:sticker?)
  end
end
