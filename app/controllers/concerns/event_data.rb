module EventData
  extend ActiveSupport::Concern

  include FavoriteUsers

  def set_event
    @event = Event.includes(:event_participations).find_by(slug: params[:event_slug])
    redirect_to root_path, status: :moved_permanently unless @event
  end

  def set_event_meta_tags
    set_meta_tags(@event)
  end

  def set_participation
    @participation ||= Current.user&.main_participation_to(@event)
  end

  def set_participants
    # Resolve verified attendee user IDs for this event
    @verified_participant_ids = VerifiedEventParticipation
      .where(event: @event)
      .joins("INNER JOIN connected_accounts ON connected_accounts.uid = verified_event_participations.connect_id AND connected_accounts.provider = 'passport'")
      .distinct
      .pluck("connected_accounts.user_id")
      .to_set

    # Start with self-reported participants
    participants = @event.participants.preloaded.order(:name).distinct

    # Add verified-only users (have verified attendance but no self-reported participation)
    verified_only_ids = @verified_participant_ids - participants.map(&:id).to_set
    all_participants = participants.to_a
    if verified_only_ids.any?
      all_participants += User.preloaded.where(id: verified_only_ids).order(:name).to_a
    end

    if Current.user
      @participants = {
        "Ruby Friends" => [],
        "Favorites" => [],
        "Known Participants" => []
      }
      all_participants.each do |participant|
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
      @participants = {"Known Participants" => all_participants}
    end
  end
end
