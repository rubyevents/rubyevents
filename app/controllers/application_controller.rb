class ApplicationController < ActionController::Base
  include Authenticable
  include Metadata
  include Analytics
  include Localizable

  prepend_before_action :redirect_to_ruby_events

  helper_method :default_watch_list

  def default_watch_list
    @default_watch_list ||= Current.user&.default_watch_list
  end

  private

  def redirect_to_ruby_events
    return if Rails.env.local?
    return if hotwire_native_app?
    return if request.url.match?(/rubyevents\.org/)

    path = request.path
    query_string = request.query_parameters.present? ? "?#{request.query_parameters.to_query}" : ""
    ruby_events_url = Rails.env.production? ? "https://www.rubyevents.org#{path}#{query_string}" : "https://staging.rubyevents.org#{path}#{query_string}"
    redirect_to ruby_events_url, status: :moved_permanently, allow_other_host: true
  end

  def sign_in(user)
    user.sessions.create!.tap do |session|
      cookies.signed.permanent[:session_token] = {value: session.id, httponly: true}
    end
  end
end
