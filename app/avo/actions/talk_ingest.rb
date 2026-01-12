class Avo::Actions::TalkIngest < Avo::BaseAction
  self.name = "Ingest talk (fetch transcript, enhance transcript, summarize, extract topics)"

  def handle(query:, fields:, current_user:, resource:, **args)
    query.each do |record|
      record.agents.ingest_later
    end

    succeed "Ingesting the talks in the background"
  end
end
