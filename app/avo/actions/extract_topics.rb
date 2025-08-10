class Avo::Actions::ExtractTopics < Avo::BaseAction
  self.name = 'Extract Topics'

  def handle(query:, fields:, current_user:, resource:, **args)
    query.each do |talk|
      TalksAgent.with(talk_id: talk.id).analyze_topics.generate_later
    end
  end
end
