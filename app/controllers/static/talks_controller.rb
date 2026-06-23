# frozen_string_literal: true

module Static
  class TalksController < ApplicationController
    before_action :require_admin!
    before_action :set_static_event
    before_action :set_talk, only: %i[edit update destroy]

    # GET /static/events/:event_slug/talks
    def index
      @talks = @static_event.talks
    end

    # GET /static/events/:event_slug/talks/new
    def new
    end

    # POST /static/events/:event_slug/talks
    def create
      @static_event.talks.create(**talk_attributes)

      redirect_to static_event_talks_path(@static_event.slug), notice: "Talk created successfully."
    rescue => e
      redirect_to new_static_event_talk_path(@static_event.slug), alert: "Failed to create talk: #{e.message}"
    end

    # GET /static/events/:event_slug/talks/:id/edit
    def edit
    end

    # PATCH /static/events/:event_slug/talks/:id
    def update
      @talk.update(**talk_attributes)

      redirect_to static_event_talks_path(@static_event.slug), notice: "Talk updated successfully."
    rescue => e
      redirect_to edit_static_event_talk_path(@static_event.slug, @talk.id), alert: "Failed to update talk: #{e.message}"
    end

    # DELETE /static/events/:event_slug/talks/:id
    def destroy
      @talk.id
      @talk.destroy

      redirect_to static_event_talks_path(@static_event.slug), notice: "Talk deleted successfully."
    rescue => e
      redirect_to static_event_talks_path(@static_event.slug), alert: "Failed to delete talk: #{e.message}"
    end

    private

    def set_static_event
      @static_event = Static::Event.find_by_slug(params[:event_slug])

      redirect_to events_path, alert: "Event not found." unless @static_event
    end

    def set_talk
      @talk = @static_event.talks.find_by(id: params[:id])

      redirect_to static_event_talks_path(@static_event.slug), alert: "Talk not found." unless @talk
    end

    def require_admin!
      redirect_to root_path, alert: "Not authorized" unless Current.user&.admin?
    end

    def talk_attributes
      attrs = params.require(:talk).permit(
        :id, :title, :description, :date, :video_provider, :video_id,
        :kind, :slides_url, :language, :start_cue, :end_cue,
        :published_at, :raw_title, :track, :event_name, :status
      ).to_h.symbolize_keys

      # Remove blank optional fields so we don't overwrite existing values with ""
      attrs.reject! { |_, v| v.blank? }

      # Convert speakers from comma-separated string to array
      speakers_param = params[:talk][:speakers]
      if speakers_param.present?
        attrs[:speakers] = speakers_param.split(",").map(&:strip).compact_blank
      end

      attrs
    end
  end
end
