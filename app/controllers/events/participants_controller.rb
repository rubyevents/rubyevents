class Events::ParticipantsController < ApplicationController
  include FavoriteUsers

  skip_before_action :authenticate_user!, only: %i[index]
  before_action :set_event
  before_action :set_favorite_users, only: %i[index]

  def index
    participants = @event.participants.preloaded.order(:name).distinct
    if Current.user
      @participants = {
        "Ruby Friends" => [],
        "Favorites" => [],
        "Known Participants" => []
      }
      participants.each do |participant|
        fav_user = @favorite_users[participant.id]
        if fav_user&.ruby_friend?
          @participants["Ruby Friends"] << participant
        elsif fav_user&.persisted?
          @participants["Favorites"] << participant
        else
          @participants["Known Participants"] << participant
        end
      end
    else
      @participants = {"Known Participants" => participants}
    end
    @participation = Current.user&.main_participation_to(@event)
  end

  private

  def set_event
    @event = Event.includes(:event_participations).find_by(slug: params[:event_slug])
    redirect_to root_path, status: :moved_permanently unless @event
  end
end
