Rails.application.configure do
  # YJIT slows down the test suite and doesn't really help in development
  # It will be disabled by default in Rails 8.1
  # https://github.com/rails/rails/pull/53746

  config.yjit = !Rails.env.local?
end
