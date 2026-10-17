# frozen_string_literal: true

ReActionView.configure do |config|
  # Intercept .html.erb templates and process them with `Herb::Engine` for enhanced features
  config.intercept_erb = true

  # Enable debug mode in development (adds debug attributes to HTML)
  config.debug_mode = Rails.env.development?

  # Instrumentation failing on methods with no signature
  config.instrumentation[:enabled] = false

  # Add custom transform visitors to process templates before compilation
  # config.transform_visitors = [
  #   Herb::Visitor::new
  # ]
end
