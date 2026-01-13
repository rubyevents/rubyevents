module Router
  class << self
    include Rails.application.routes.url_helpers

    def image_path(...)
      ActionController::Base.helpers.image_path(...)
    end

    def image_url(...)
      ActionController::Base.helpers.image_url(...)
    end
  end
end
