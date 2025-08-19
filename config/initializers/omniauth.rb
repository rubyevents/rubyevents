Rails.application.config.middleware.use OmniAuth::Builder do
  provider :developer, fields: [:name, :github_handle] unless Rails.env.production? # You should replace it with your provider

  github_client_id = Rails.application.credentials.dig(:github, :client_id) || ENV["GITHUB_CLIENT_ID"]
  github_client_secret = Rails.application.credentials.dig(:github, :client_secret) || ENV["GITHUB_CLIENT_SECRET"]
  provider :github, github_client_id, github_client_secret, scope: "read:user,user:email"
end
