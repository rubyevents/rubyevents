module Authenticable
  extend ActiveSupport::Concern

  included do
    before_action :set_current_request_details
    before_action :authenticate_user!

    helper_method :signed_in?, :signed_in, :signed_out
  end

  def signed_in?
    Current.user.present?
  end

  def signed_in(&block)
    yield if block && signed_in?
  end

  def signed_out(&block)
    yield if block && !signed_in?
  end

  private

  def authenticate_user!
    redirect_to new_session_path unless Current.user
  end

  def set_current_request_details
    Current.user_agent = request.user_agent
    Current.ip_address = request.ip
    Current.session = Session.find_by_id(cookies.signed[:session_token]) if cookies.signed[:session_token]
  end
end
