class Avo::Actions::AssignCanonicalSpeaker < Avo::BaseAction
  self.name = "Assign Canonical Speaker"
  # self.visible = -> do
  #   true
  # end

  def fields
    field :speaker_id, as: :select, name: "Canonical speaker",
      help: "The name of the speaker to be set as canonical",
      options: -> { User.speakers.order(:name).pluck(:name, :id) }
  end

  def handle(query:, fields:, current_user:, resource:, **args)
    canonical_speaker = User.find(fields[:speaker_id])

    query.each do |record|
      record.assign_canonical_speaker!(canonical_speaker: canonical_speaker)
    end

    succeed "Assigning canonical speaker #{canonical_speaker.name} to #{query.count} speakers"
    redirect_to avo.resources_user_path(canonical_speaker), status: :permanent_redirect
  end
end
