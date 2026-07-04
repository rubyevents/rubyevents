class PageController < ApplicationController
  skip_before_action :authenticate_user!

  def home
    home_page_cached_data = Rails.cache.fetch("home_page_content", expires_in: 1.hour) do
      {
        talks_count: Talk.count,
        speakers_count: User.speakers.count,
        events_count: Event.count
      }
    end

    @talks_count = home_page_cached_data[:talks_count]
    @speakers_count = home_page_cached_data[:speakers_count]
    @events_count = home_page_cached_data[:events_count]

    today = Date.today
    base = Event.distinct.not_meetup.featurable.where.not(home_sort_date: nil)

    featured_ids = (
      base.where.not(recordings_published_date: nil).pluck(:id) +
      base.with_talks.where(start_date: ..today, end_date: today..).pluck(:id) +
      base.with_talks.where(end_date: (today - Event::FEATURED_RECENTLY_ENDED_WINDOW)..today.prev_day).pluck(:id) +
      base.with_talks.where(start_date: today.next_day..(today + Event::FEATURED_UPCOMING_WINDOW)).pluck(:id) +
      base.joins(:cfps).where(cfps: {close_date: today..(today + Event::FEATURED_CFP_CLOSING_WINDOW)}).where.not(cfps: {link: nil}).pluck(:id)
    ).uniq

    featured_ids = Event.where(id: featured_ids)
      .includes(:cfps)
      .sort_by { |event| event.featured_distance(today: today) }
      .first(15)
      .map(&:id)

    @featured_events = Event
      .where(id: featured_ids)
      .includes(:series, :keynote_speakers, :speakers, :cfps)
      .in_order_of(:id, featured_ids)

    respond_to do |format|
      format.html
      format.json {
        latest_talks = Talk.watchable.with_speakers.includes(event: :series).order(date: :desc).limit(10)
        upcoming_talks = Talk.with_speakers.includes(event: :series).where(date: Date.today..).order(date: :asc).limit(15)
        featured_speakers = User.with_github.joins(:talks).where(talks: {date: 12.months.ago..}).order(Arel.sql("RANDOM()")).limit(10)

        render json: {
          featured: @featured_events.map { |event| event.to_mobile_json(request) },
          talks: [
            {
              name: "Latest Recordings",
              items: latest_talks.map { |talk| talk.to_mobile_json(request) },
              url: talks_url
            },
            {
              name: "Upcoming Talks",
              items: upcoming_talks.map { |talk| talk.to_mobile_json(request) },
              url: talks_url
            }
          ],
          speakers: [
            {
              name: "Active Speakers",
              items: featured_speakers.map { |speaker| speaker.to_mobile_json(request) },
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

  def attend
  end

  def speak
  end

  def organize
  end

  def stickers
    @events = Event.all.select(&:sticker?)
    @stickers = @events.flat_map(&:stickers)
  end

  def contributors
    @contributors = Contributor.includes(:user).order(:name, :login)
  end

  def assets
    @events = Event.includes(:series).order("event_series.name, events.name")

    @asset_types = {
      "avatar" => {width: 256, height: 256, name: "Avatar"},
      "banner" => {width: 1300, height: 350, name: "Banner"},
      "card" => {width: 600, height: 350, name: "Card"},
      "featured" => {width: 615, height: 350, name: "Featured"},
      "poster" => {width: 600, height: 350, name: "Poster"},
      "sticker" => {width: 350, height: 350, name: "Sticker"},
      "stamp" => {width: 512, height: 512, name: "Stamp"}
    }

    @events_with_assets = @events.map do |event|
      assets = {}
      @asset_types.except("sticker", "stamp").each do |type, _|
        asset_path = event.event_image_for("#{type}.webp")
        assets[type] = asset_path.present?
      end

      sticker_paths = event.sticker_image_paths
      stamp_paths = event.stamp_image_paths

      {
        event: event,
        assets: assets,
        has_any_assets: assets.values.any?,
        missing_assets: assets.select { |_, exists| !exists }.keys,
        sticker_paths: sticker_paths,
        stamp_paths: stamp_paths
      }
    end
  end
end
