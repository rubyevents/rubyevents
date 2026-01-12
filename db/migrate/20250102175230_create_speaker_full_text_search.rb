class CreateSpeakerFullTextSearch < ActiveRecord::Migration[8.0]
  def up
    create_virtual_table :speakers_search_index, :fts5, [
      "name", "github", "tokenize = porter"
    ]

    Speaker.reindex_all
  end

  def down
    drop_table :speakers_search_index
  end
end
