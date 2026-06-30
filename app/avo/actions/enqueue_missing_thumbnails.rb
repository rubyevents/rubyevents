class Avo::Actions::EnqueueMissingThumbnails < Avo::BaseAction
  self.name = "Enqueue missing thumbnails"
  self.standalone = true

  def handle(query:, fields:, current_user:, resource:, **args)
    scope = Talk.needing_generated_thumbnail.includes(:speakers).with_attached_generated_thumbnail
    enqueued = 0

    scope.find_each do |talk|
      next if Talk::ThumbnailGenerator.new(talk, variant: "spotlight").exists?

      GenerateTalkThumbnailJob.perform_later(talk, "spotlight")
      enqueued += 1
    end

    succeed "Enqueued #{enqueued} missing thumbnail(s) in the background"
  end
end
