class Sessions::OmniauthController < ApplicationController
  skip_before_action :verify_authenticity_token
  skip_before_action :authenticate_user!

  def create
    connected_account = ConnectedAccount.find_or_initialize_by(provider: omniauth.provider, uid: omniauth.uid)

    if connected_account.new_record?
      @user = User.find_or_create_by(email: github_email) do |user|
        user.password = SecureRandom.base58
        user.verified = true
        user.github_handle = omniauth.info&.try(:nickname)
      end
      connected_account.user = @user
      connected_account.access_token = token
      connected_account.username = omniauth.info&.try(:nickname)
      connected_account.save!
    else
      @user = connected_account.user
    end

    if @user.persisted?
      @user.update(name: name) if name.present?

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

  def github_email
    @github_email ||= omniauth.info.email || fetch_github_email(token)
  end

  def token
    @token ||= omniauth.credentials&.token
  end

  def name
    @name ||= omniauth.info&.try(:name)
  end

  def redirect_to_path
    query_params["redirect_to"] || root_path
  end

  def omniauth_params
    {provider: omniauth.provider, uid: omniauth.uid, username: omniauth.info.try(:nickname)}.compact_blank
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
