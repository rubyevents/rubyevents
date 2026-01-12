class Events::SpeakersController < ApplicationController
  skip_before_action :authenticate_user!, only: %i[index]
  before_action :set_event, only: %i[index]

  def index
    if @event.meetup?
      # For meetups, get speakers with their talk counts at this specific meetup
      # and sort by number of talks (descending)
      speaker_ids = @event.talks.joins(:user_talks).pluck("user_talks.user_id")
      speaker_counts = speaker_ids.tally

      @speakers_with_counts = User
        .preloaded
        .where(id: speaker_counts.keys)
        .where("talks_count > 0")
        .map do |speaker|
          # Add the meetup-specific talk count
          speaker.define_singleton_method(:meetup_talks_count) { speaker_counts[speaker.id] }
          speaker
        end
        .sort_by { |s| [-s.meetup_talks_count, s.name] }
    end
  end

  private

  def set_event
    @event = Event.includes(:series, talks: {speakers: :connected_accounts}).find_by(slug: params[:event_slug])
    return redirect_to(root_path, status: :moved_permanently) unless @event

    set_meta_tags(@event)

    redirect_to schedule_event_path(@event.canonical), status: :moved_permanently if @event.canonical.present?
  end
end
