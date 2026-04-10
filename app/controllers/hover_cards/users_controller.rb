# frozen_string_literal: true

class HoverCards::UsersController < ApplicationController
  skip_before_action :authenticate_user!

  ALLOWED_AVATAR_SIZES = %w[sm md lg].freeze

  def show
    @user = User.find_by_slug_or_alias(params[:slug])
    @user ||= User.find_by_github_handle(params[:slug])

    if @user.blank? || @user.suspicious?
      head :not_found
      return
    end

    return redirect_to profile_path(@user) unless turbo_frame_request?

    @avatar_size = ALLOWED_AVATAR_SIZES.include?(params[:avatar_size]) ? params[:avatar_size].to_sym : :sm

    render layout: false
  end
end
