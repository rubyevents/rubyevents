class Avo::Actions::Summarize < Avo::BaseAction
  self.name = "Summarize"

  def handle(query:, fields:, current_user:, resource:, **args)
    query.each do |talk|
      talk.agents.summarize_later
    end
  end
end
