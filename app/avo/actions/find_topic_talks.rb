class Avo::Actions::FindTopicTalks < Avo::BaseAction
  self.name = "Find Talks"

  def handle(query:, fields:, current_user:, resource:, **args)
    query.each do |topic|
      topic.agents.find_talks_later
    end

    succeed "Enqueued job to find talks for #{query.count} topic(s)"
  end
end
