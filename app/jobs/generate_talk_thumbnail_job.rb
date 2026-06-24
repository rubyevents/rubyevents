class GenerateTalkThumbnailJob < ApplicationJob
  queue_as :default
  limits_concurrency to: 1, key: "generate_talk_thumbnail", duration: 5.minutes

  def perform(talk, variant = Talk::ThumbnailGenerator::DEFAULT_VARIANT)
    Talk::ThumbnailGenerator.new(talk, variant: variant).save_to_storage
  end
end
