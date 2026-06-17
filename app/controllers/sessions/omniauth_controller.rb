class Sessions::OmniauthController < ApplicationController
  skip_before_action :verify_request_for_forgery_protection
  skip_before_action :authenticate_user!

  def create
    state_values = parse_state(state)
    connect_id = state_values["connect_id"]
    connect_to = state_values["connect_to"]
    native_platform = state_values["native"]

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

      if native_platform.present?
        signin_token = @user.signed_id(purpose: :native_signin, expires_in: 60.seconds)
        redirect_to "rubyevents://auth/#{omniauth.provider}/callback?token=#{signin_token}", allow_other_host: true
      else
        sign_in @user

        if connect_id.present?
          redirect_to profile_path(@user), notice: "🙌 Congrats you claimed your passport"
        else
          redirect_to redirect_to_path, notice: "Signed in successfully"
        end
      end
    else
      redirect_to new_session_path, alert: "Authentication failed"
    end
  end

  def failure
    redirect_to new_session_path, alert: params[:message]
  end

  private

  def parse_state(state)
    return {} if state.blank?
    state.split("|").each_with_object({}) do |pair, hash|
      key, value = pair.split(":", 2)
      hash[key] = value if key.present?
    end
  end

  def omniauth_username
    omniauth_params[:username]
  end

  def initialize_user
    User.new(github_handle: omniauth_username) do |user|
      user.password = SecureRandom.base58
      user.name = omniauth_params[:name]
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
