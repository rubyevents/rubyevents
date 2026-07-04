class Avo::Actions::RegenerateThumbnail < Avo::BaseAction
  self.name = "Regenerate thumbnail"

  def handle(query:, fields:, current_user:, resource:, **args)
    query.each do |record|
      record.generated_thumbnail.purge if record.generated_thumbnail.attached?
      GenerateTalkThumbnailJob.perform_later(record, "spotlight")
    end

    succeed "Regenerating #{query.size} thumbnail(s) in the background"
  end
end
