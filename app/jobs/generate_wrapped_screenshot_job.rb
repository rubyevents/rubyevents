class GenerateWrappedScreenshotJob < ApplicationJob
  queue_as :default

  def perform(user)
    User::WrappedScreenshotGenerator.generate_all(user)
  end
end
