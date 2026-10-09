class Avo::Actions::ValidateThumbnail < Avo::BaseAction
  self.name = "Validate thumbnail"

  def handle(query:, fields:, current_user:, resource:, **args)
    query.each do |record|
      record.validate_thumbnail!
    end

    succeed "Thumbnail validation complete"
  end
end
