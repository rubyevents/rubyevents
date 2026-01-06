class AddVideoProviderToTalksSearchIndex < ActiveRecord::Migration[8.0]
  def up
    # Drop and recreate FTS table with video_provider as unindexed column
    # Unindexed columns are stored but not searchable - perfect for filtering
    drop_table :talks_search_index

    create_virtual_table :talks_search_index, :fts5, [
      "title",
      "summary",
      "speaker_names",
      "event_names",
      "video_provider UNINDEXED", # For filtering, not searching
      "tokenize = porter"
    ]

    # Reindex all talks (this will be slow but only runs once)
    Talk.includes(:speakers, :event).find_each do |talk|
      execute <<~SQL.squish
        INSERT INTO talks_search_index (rowid, title, summary, speaker_names, event_names, video_provider)
        VALUES (
          #{talk.id},
          #{connection.quote(talk.title)},
          #{connection.quote(talk.summary.to_s)},
          #{connection.quote(talk.speaker_names)},
          #{connection.quote(talk.event_names)},
          #{connection.quote(talk.video_provider)}
        )
      SQL
    end
  end

  def down
    drop_table :talks_search_index

    create_virtual_table :talks_search_index, :fts5, [
      "title",
      "summary",
      "speaker_names",
      "event_names",
      "tokenize = porter"
    ]

    # Reindex all talks
    Talk.includes(:speakers, :event).find_each do |talk|
      execute <<~SQL.squish
        INSERT INTO talks_search_index (rowid, title, summary, speaker_names, event_names)
        VALUES (
          #{talk.id},
          #{connection.quote(talk.title)},
          #{connection.quote(talk.summary.to_s)},
          #{connection.quote(talk.speaker_names)},
          #{connection.quote(talk.event_names)}
        )
      SQL
    end
  end
end
