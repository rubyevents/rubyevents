class CreateTalkFts < ActiveRecord::Migration[7.2]
  def up
    create_virtual_table :talks_search_index, :fts5, [
      "title", "summary", "speaker_names",
      "tokenize = porter"
    ]

    Talk.reindex_all
  end

  def down
    drop_table :talks_search_index
  end
end
