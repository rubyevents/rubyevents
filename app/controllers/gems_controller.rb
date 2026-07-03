class GemsController < ApplicationController
  include Pagy::Backend
  include WatchedTalks

  skip_before_action :authenticate_user!
  before_action :set_gem, only: [:show, :talks]
  before_action :set_user_favorites, only: [:show, :talks]

  def index
    @gems = TopicGem
      .joins(:topic)
      .where(topics: {status: :approved})
      .select("topic_gems.*, topics.talks_count as talks_count")
      .order("topics.talks_count DESC")

    @gems = @gems.where("lower(gem_name) LIKE ?", "#{params[:letter].downcase}%") if params[:letter].present?
    @pagy, @gems = pagy(@gems, limit: 50, page: page_number)

    set_meta_tags(
      title: "Ruby Gems",
      description: "Browse Ruby gems featured in conference talks"
    )
  end

  def show
    @talks = @topic.talks.includes(:speakers, event: :series).order(date: :desc).limit(8)

    set_meta_tags(
      title: @gem.gem_name,
      description: "Watch #{@topic.talks_count} conference talks about #{@gem.gem_name}"
    )
  end

  def talks
    @pagy, @talks = pagy_countless(
      @topic.talks.includes(:speakers, event: :series).order(date: :desc),
      limit: 24,
      page: page_number
    )

    set_meta_tags(
      title: "Talks about #{@gem.gem_name}",
      description: "Watch #{@topic.talks_count} conference talks about #{@gem.gem_name}"
    )
  end

  private

  def set_gem
    @gem = TopicGem.find_by!(gem_name: params[:gem_name])
    @topic = @gem.topic
  end

  def set_user_favorites
    return unless Current.user

    @user_favorite_talks_ids = Current.user.default_watch_list.talks.ids
  end

  def page_number
    [params[:page]&.to_i, 1].compact.max
  end
end
