class ConsolidateLanguagePreferencesOnUsers < ActiveRecord::Migration[8.2]
  def change
    add_column :users, :language_preferences, :json, default: {}, null: false
    remove_column :users, :spoken_languages, :json, default: [], null: false
  end
end
