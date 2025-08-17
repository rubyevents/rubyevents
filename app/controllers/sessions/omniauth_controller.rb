class Sessions::OmniauthController < ApplicationController
  skip_before_action :verify_authenticity_token
  skip_before_action :authenticate_user!

  def create
    connected_account = ConnectedAccount.find_or_initialize_by(provider: omniauth.provider, username: omniauth_params[:username])

    if connected_account.new_record?
      @user = User.find_or_initialize_by(github_handle: omniauth_params[:username]) do |user|
        user.password = SecureRandom.base58
        user.name = omniauth_params[:name]
        user.slug = omniauth_params[:username]
        user.email = omniauth_params[:email]
        user.verified = true
      end
      connected_account.user = @user
      connected_account.access_token = token
      connected_account.username = omniauth_params[:username]
      connected_account.save!
    else
      @user = connected_account.user
    end

    if @user.persisted?
      @user.update(name: omniauth_params[:name]) if omniauth_params[:name].present?

      sign_in @user

      redirect_to redirect_to_path, notice: "Signed in successfully"
    else
      redirect_to new_session_path, alert: "Authentication failed"
    end
  end

  def failure
    redirect_to new_session_path, alert: params[:message]
  end

  private

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
    query_params["redirect_to"] || root_path
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

  def fetch_github_email(oauth_token)
    return unless oauth_token
    response = GitHub::UserClient.new(token: oauth_token).emails

    emails = response.parsed_body
    primary_email = emails.find { |email| email.primary && email.verified }
    primary_email&.email
  end
end
