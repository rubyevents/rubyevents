class RemoveGitHubOfSpeakerWithCanonical < ActiveRecord::Migration[8.0]
  def change
    Speaker.where.not(canonical_id: nil).update_all(github: "")
  end
end
