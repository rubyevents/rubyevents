class Avo::Actions::Summarize < Avo::BaseAction
  self.name = 'Summarize'

  def handle(query:, fields:, current_user:, resource:, **args)
    query.each do |talk|
      TalksAgent.with(talk_id: talk.id).summarize.generate_later
    end
  end
end
