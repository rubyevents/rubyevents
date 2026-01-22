class AnnouncementsController < ApplicationController
  include Pagy::Backend

  skip_before_action :authenticate_user!

  def index
    announcements = can_view_draft_articles? ? Announcement.all : Announcement.published
    @current_tag = params[:tag]

    if @current_tag.present?
      announcements = announcements.select { |a| a.tags.map(&:downcase).include?(@current_tag.downcase) }
    end

    @pagy, @announcements = pagy_array(announcements, limit: 10, page: page_number)
  end

  def show
    @announcement = Announcement.find_by_slug!(params[:slug])

    unless @announcement.published? || can_view_draft_articles?
      raise ActiveRecord::RecordNotFound
    end

    set_meta_tags(
      title: @announcement.title,
      description: @announcement.excerpt
    )
  end

  def feed
    @announcements = Announcement.published.first(20)

    respond_to do |format|
      format.rss { render layout: false }
    end
  end

  private

  def page_number
    [params[:page]&.to_i, 1].compact.max
  end

  def can_view_draft_articles?
    Current.user&.admin? || Rails.env.development? || params[:preview] == "true"
  end
end
