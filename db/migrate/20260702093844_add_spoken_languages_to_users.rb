class AddSpokenLanguagesToUsers < ActiveRecord::Migration[8.2]
  def change
    add_column :users, :spoken_languages, :json, default: [], null: false
  end
end
