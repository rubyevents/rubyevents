class Events::ArchiveController < ApplicationController
  skip_before_action :authenticate_user!, only: %i[index]

  def index
    @events = Event.canonical.includes(:series).order("events.name ASC")
    @events = @events.where("lower(events.name) LIKE ?", "#{params[:letter].downcase}%") if params[:letter].present?
    @events = @events.ft_search(params[:s]) if params[:s].present?
  end
end
