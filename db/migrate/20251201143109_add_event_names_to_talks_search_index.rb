class AddEventNamesToTalksSearchIndex < ActiveRecord::Migration[8.1]
  def up
    drop_table :talks_search_index

    create_virtual_table :talks_search_index, :fts5, [
      "title", "summary", "speaker_names", "event_names",
      "tokenize = porter"
    ]

    Talk.reindex_all
  end

  def down
    drop_table :talks_search_index

    create_virtual_table :talks_search_index, :fts5, [
      "title", "summary", "speaker_names",
      "tokenize = porter"
    ]

    Talk.reindex_all
  end
end
