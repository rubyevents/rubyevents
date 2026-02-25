module Analytics
  extend ActiveSupport::Concern

  included do
    after_action :track_action, unless: :analytics_disabled?
  end

  class_methods do
    def disable_analytics
      @analytics_disabled = true
    end
  end

  private

  def analytics_disabled?
    self.class.instance_variable_get(:@analytics_disabled)
  end

  def track_action
    ahoy.track "#{controller_path}##{action_name}", request.params
  end
end
