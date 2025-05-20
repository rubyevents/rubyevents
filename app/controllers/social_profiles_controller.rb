class SocialProfilesController < ApplicationController
  skip_before_action :authenticate_user!, only: [:edit, :update]
  before_action :check_ownership, only: [:new, :create]
  before_action :check_provider, only: [:new]
  before_action :set_social_profile, only: [:edit, :update]

  def new
    @social_profile = @sociable.social_profiles.new(provider: params[:provider])
  end

  def create
    @social_profile = @sociable.social_profiles.new(social_profile_params)

    begin
      ActiveRecord::Base.transaction do
        @social_profile.save!
        @suggestion = @social_profile.create_suggestion_from(
          params: @social_profile.attributes.slice("provider", "value"),
          new_record: true
        )
      end
    rescue ActiveRecord::RecordInvalid
    end

    respond_to do |format|
      if @suggestion&.persisted?
        flash[:notice] = "Saved"
        format.turbo_stream
      else
        format.turbo_stream { render :create, status: :unprocessable_entity }
      end
    end
  end

  def edit
  end

  def update
    begin
      @suggestion = @social_profile.create_suggestion_from(params: social_profile_params, user: Current.user)
    rescue ActiveRecord::RecordInvalid
    end

    respond_to do |format|
      if @suggestion&.persisted?
        flash[:notice] = "Saved"
        format.turbo_stream
      else
        format.turbo_stream { render :update, status: :unprocessable_entity }
      end
    end
  end

  private

  def social_profile_params
    params.require(:social_profile).permit(
      :provider,
      :value
    )
  end

  def set_social_profile
    @social_profile ||= SocialProfile.find(params[:id])
  end

  def check_provider
    raise StandardError, "Invalid Social Provider" unless SocialProfile::PROVIDERS.include?(params[:provider])
  end

  def check_ownership
    head :forbidden unless @sociable.managed_by?(Current.user)
  end
end
