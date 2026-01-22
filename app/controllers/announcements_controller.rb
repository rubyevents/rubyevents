class AnnouncementsController < ApplicationController
  include Pagy::Backend

  skip_before_action :authenticate_user!

  def index
    @current_tag = params[:tag]
    filtered_announcements = announcements
    filtered_announcements = filtered_announcements.by_tag(@current_tag) if @current_tag.present?

    @pagy, @announcements = pagy_array(filtered_announcements, limit: 10, page: page_number)
  end

  def show
    @announcement = announcements.find_by_slug!(params[:slug])

    unless @announcement.published? || can_view_draft_articles?
      raise ActiveRecord::RecordNotFound
    end

    set_meta_tags(
      title: @announcement.title,
      description: @announcement.excerpt
    )
  end

  def feed
    @current_tag = params[:tag]
    announcements = Announcement.published
    announcements = announcements.by_tag(@current_tag) if @current_tag.present?
    @announcements = announcements.first(20)

    respond_to do |format|
      format.rss { render layout: false }
    end
  end

  private

  def announcements
    @announcements ||= can_view_draft_articles? ? Announcement.all : Announcement.published
  end

  def page_number
    [params[:page]&.to_i, 1].compact.max
  end

  def can_view_draft_articles?
    Current.user&.admin? || params[:preview] == "true"
    # Current.user&.admin? || Rails.env.development? || params[:preview] == "true"
  end

  helper_method :permitted_params
  def permitted_params
    {preview: can_view_draft_articles? ? "true" : nil}.compact
  end
end
