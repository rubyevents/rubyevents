class Avo::Actions::ExtractTopics < Avo::BaseAction
  self.name = "Extract Topics"

  def handle(query:, fields:, current_user:, resource:, **args)
    query.each do |talk|
      talk.agents.analyze_topics_later
    end
  end
end
