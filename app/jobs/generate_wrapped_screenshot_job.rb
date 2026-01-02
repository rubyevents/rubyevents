class GenerateWrappedScreenshotJob < ApplicationJob
  queue_as :default
  limits_concurrency to: 1, key: "generate_wrapped_screenshot", duration: 5.minutes


  def perform(user)
    User::WrappedScreenshotGenerator.generate_all(user)
  end
end
