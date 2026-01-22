class AnnouncementsController < ApplicationController
  include Pagy::Backend

  skip_before_action :authenticate_user!

  def index
    announcements = Current.user&.admin? ? Announcement.all : Announcement.published
    @pagy, @announcements = pagy_array(announcements, limit: 10, page: page_number)
  end

  def show
    @announcement = Announcement.find_by_slug!(params[:slug])

    unless @announcement.published? || Current.user&.admin?
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
end
