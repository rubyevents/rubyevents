class ApplicationController < ActionController::Base
  include Authenticable
  include Metadata
  include Analytics

  prepend_before_action :redirect_to_ruby_events
  after_action :set_markdown_alternate_headers

  helper_method :default_watch_list, :markdown_alternate_url

  def default_watch_list
    @default_watch_list ||= Current.user&.default_watch_list
  end

  # Absolute URL of the Markdown twin of the current page, when one exists. Set
  # by content actions (talks, profiles, events, topics) and surfaced to crawlers
  # via the layout (<link rel="alternate">) and the Link response header.
  attr_reader :markdown_alternate_url

  private

  def set_markdown_alternate_headers
    return if @markdown_alternate_url.blank? || !request.format.html?

    response.headers["Link"] = %(<#{@markdown_alternate_url}>; rel="alternate"; type="text/markdown")
    response.headers["Vary"] = [response.headers["Vary"].presence, "Accept"].compact.uniq.join(", ")
  end

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
