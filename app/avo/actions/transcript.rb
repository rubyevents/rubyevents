class Avo::Actions::Transcript < Avo::BaseAction
  self.name = "Fetch raw transcript"

  def handle(query:, fields:, current_user:, resource:, **args)
    query.each do |record|
      record.fetch_and_update_raw_transcript_later!
    end

    succeed "Fetching the transcript in the background"
  end
end
