class GenerateTalkThumbnailJob < ApplicationJob
  queue_as :thumbnails

  def perform(talk, variant = Talk::ThumbnailGenerator::DEFAULT_VARIANT)
    generator = Talk::ThumbnailGenerator.new(talk, variant: variant)
    return if generator.exists?

    generator.save_to_storage
  end
end
