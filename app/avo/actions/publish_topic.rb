class Avo::Actions::PublishTopic < Avo::BaseAction
  self.name = "Publish Topic"

  def handle(query:, fields:, current_user:, resource:, **args)
    query.each do |record|
      record.update(published: true)
    end
  end
end
