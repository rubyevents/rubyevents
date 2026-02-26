class ImageProxyController < ApplicationController
  disable_analytics
  skip_before_action :authenticate_user!

  def github_avatar
    user = User.find(params[:id])
    size = params[:size] || 200

    cache_key = "image_proxy/github_avatar/#{user.id}/#{size}"
    avatar_data = Rails.cache.fetch(cache_key, expires_in: 1.day) do
      fetch_github_avatar(user, size) || fetch_fallback_avatar(user, size)
    end

    if avatar_data
      expires_in 1.day, public: true
      fresh_when etag: cache_key, last_modified: 1.day.ago, public: true
      send_data avatar_data,
        type: "image/png",
        disposition: "inline"
    else
      head :not_found
    end
  end

  private

  def fetch_github_avatar(user, size)
    username = user.github_handle
    return if username.empty?

    url = "https://github.com/#{username}.png?size=#{size}"
    fetch_image(url)
  end

  def fetch_fallback_avatar(user, size)
    url_safe_initials = user.name.split(" ").map(&:first).join("+")
    url = "https://ui-avatars.com/api/?name=#{url_safe_initials}&size=#{size}&background=DC133C&color=fff"
    fetch_image(url)
  end

  def fetch_image(url)
    response = HTTParty.get(url)
    response.success? ? response.body : nil
  rescue
    nil
  end
end
