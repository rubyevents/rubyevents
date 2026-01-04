class Sessions::OmniauthController < ApplicationController
  skip_before_action :verify_request_for_forgery_protection
  skip_before_action :authenticate_user!

  def create
    # This needs to be refactored to be more robust when we have more states
    if state.present?
      key, value = state.split(":")
      connect_id = (key == "connect_id") ? value : nil
      connect_to = (key == "connect_to") ? value : nil
    end

    connected_account = ConnectedAccount.find_or_initialize_by(provider: omniauth.provider, username: omniauth_username&.downcase)

    if connected_account.new_record?
      @user = User.find_by_github_handle(omniauth_username)
      @user ||= initialize_user
      connected_account.user = @user
      connected_account.access_token = token
      connected_account.username = omniauth_username
      connected_account.save!
    else
      @user = connected_account.user
    end

    if @user.previously_new_record?
      @user.profiles.enhance_with_github_later
    end

    # If the user connected through a passport connection URL, we need to create a connected account for it
    if connect_id.present?
      @user.connected_accounts.find_or_create_by!(provider: "passport", uid: connect_id)
    end

    if connect_to.present?
      # TODO: Create connection
      # new_friend = User.find_by(connect_id: connect_to)
    end

    if @user.persisted?
      @user.update(name: omniauth_params[:name]) if omniauth_params[:name].present?
      @user.watched_talk_seeder.seed_development_data if Rails.env.development?

      sign_in @user

      if connect_id.present?
        redirect_to profile_path(@user), notice: "🙌 Congrats you claimed your passport"
      else
        redirect_to redirect_to_path, notice: "Signed in successfully"
      end
    else
      redirect_to new_session_path, alert: "Authentication failed"
    end
  end

  def failure
    redirect_to new_session_path, alert: params[:message]
  end

  private

  def omniauth_username
    omniauth_params[:username]
  end

  def initialize_user
    User.new(github_handle: omniauth_username) do |user|
      user.password = SecureRandom.base58
      user.name = omniauth_params[:name]
      user.slug = omniauth_params[:username]
      user.email = omniauth_params[:email]
      user.verified = true
    end
  end

  def email
    if omniauth.provider == "developer"
      "#{username}@rubyevents.org"
    else
      github_email
    end
  end

  def github_email
    @github_email ||= omniauth.info.email || fetch_github_email(token)
  end

  def token
    @token ||= omniauth.credentials&.token
  end

  def redirect_to_path
    query_params["redirect_to"].presence || root_path
  end

  def username
    omniauth.info.try(:nickname) || omniauth.info.try(:github_handle)
  end

  def omniauth_params
    {
      provider: omniauth.provider,
      uid: omniauth.uid,
      username: username,
      name: omniauth.info.try(:name),
      email: email
    }.compact_blank
  end

  def omniauth
    request.env["omniauth.auth"]
  end

  def query_params
    request.env["omniauth.params"]
  end

  def state
    @state ||= query_params.dig("state")
  end

  def fetch_github_email(oauth_token)
    return unless oauth_token
    response = GitHub::UserClient.new(token: oauth_token).emails

    emails = response.parsed_body
    primary_email = emails.find { |email| email.primary && email.verified }
    primary_email&.email
  rescue => e
    # had the case of a user where this method would fail this will need to be investigated in details
    Rails.error.report(e)
    nil
  end
end
