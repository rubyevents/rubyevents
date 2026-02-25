class TopicsController < ApplicationController
  include Pagy::Backend
  include WatchedTalks

  skip_before_action :authenticate_user!
  before_action :set_user_favorites, only: %i[show]

  def index
    @topics = Topic.approved.with_talks.includes(:topic_gems).order(name: :asc)
    @topics = @topics.where("lower(name) LIKE ?", "#{params[:letter].downcase}%") if params[:letter].present?
    @pagy, @topics = pagy(@topics, limit: 100, page: page_number)
  end

  def show
    @topic = Topic.find_by(slug: params[:slug])
    return redirect_to(root_path, status: :moved_permanently) unless @topic

    @pagy, @talks = pagy_countless(
      @topic.talks.includes(:speakers, event: :series, child_talks: :speakers).order(date: :desc),
      gearbox_extra: true,
      gearbox_limit: [12, 24, 48, 96],
      overflow: :empty_page,
      page: page_number
    )
    set_meta_tags(@topic)
  end

  def set_user_favorites
    return unless Current.user

    @user_favorite_talks_ids = Current.user.default_watch_list.talks.ids
  end

  private

  def page_number
    [params[:page]&.to_i, 1].compact.max
  end
end
