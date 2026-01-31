class PageController < ApplicationController
  skip_before_action :authenticate_user!

  def home
    home_page_cached_data = Rails.cache.fetch(["home_page_content", I18n.locale], expires_in: 1.hour) do
      latest_talks = Talk.watchable.with_speakers.order(published_at: :desc).limit(10)
      {
        talks_count: Talk.count,
        speakers_count: User.speakers.count,
        events_count: Event.count,
        latest_talk_ids: latest_talks.pluck(:id),
        upcoming_talk_ids: Talk.with_speakers.where(date: Date.today..).order(date: :asc).limit(15).pluck(:id),
        latest_event_ids: Event.order(date: :desc).limit(10).pluck(:id).sample(4),
        featured_speaker_ids: User.with_github
          .joins(:talks)
          .where(talks: {date: 12.months.ago..})
          .order(Arel.sql("RANDOM()"))
          .limit(40)
          .pluck(:id)
      }
    end

    @talks_count = home_page_cached_data[:talks_count]
    @speakers_count = home_page_cached_data[:speakers_count]
    @events_count = home_page_cached_data[:events_count]
    @latest_talks = Talk.includes(event: :series).where(id: home_page_cached_data[:latest_talk_ids])
    @upcoming_talks = Talk.includes(event: :series).where(id: home_page_cached_data[:upcoming_talk_ids])
    @latest_events = Event.includes(:series).where(id: home_page_cached_data[:latest_event_ids])
    @featured_speakers = User.where(id: home_page_cached_data[:featured_speaker_ids]).sample(10)
    @featured_organizations = Organization.joins(:sponsors).includes(:events).group("organizations.id").order("COUNT(sponsors.id) DESC").limit(10)
    @recommended_talks = Current.user.talk_recommender.talks(limit: 4) if Current.user
    @wrapped_active = false && (@wrapped_users.any? || Current.user)

    imported_slugs = Event.not_meetup.with_watchable_talks.pluck(:slug)
    featurable_slugs = Static::Event.where.not(featured_background: nil).pluck(:slug)
    slug_candidates = imported_slugs & featurable_slugs

    featured_slugs = Static::Event.all
      .select { |event| slug_candidates.include?(event.slug) }
      .select(&:home_sort_date)
      .sort_by(&:home_sort_date)
      .reverse
      .take(15)
      .map(&:slug)

    @featured_events = Event.distinct
      .includes(:series, :keynote_speakers, :speakers)
      .where(slug: featured_slugs)
      .in_order_of(:slug, featured_slugs)

    @wrapped_users = User.with_public_wrapped
      .where.not(github_handle: [nil, ""])
      .order(Arel.sql("RANDOM()"))
      .limit(15)

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
