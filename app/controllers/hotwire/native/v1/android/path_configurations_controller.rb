class Hotwire::Native::V1::Android::PathConfigurationsController < ActionController::Base
  def show
    render json: {
      settings: {},
      rules: [
        {
          patterns: [
            ".*"
          ],
          properties: {
            context: "default",
            uri: "hotwire://fragment/web",
            fallback_uri: "hotwire://fragment/web",
            pull_to_refresh_enabled: true
          }
        }
      ]
    }
  end
end
