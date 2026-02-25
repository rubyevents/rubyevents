class UpdateSuggestionsSuggestable < ActiveRecord::Migration[8.1]
  def change
    Suggestion.where(suggestable_type: "Speaker").each do |suggestion|
      speaker = suggestion.suggestable
      user = User.find_by(github_handle: speaker.github) || User.find_by(slug: speaker.slug) || User.find_by(name: speaker.name)
      suggestion.update!(suggestable: user)
    end
  end
end
