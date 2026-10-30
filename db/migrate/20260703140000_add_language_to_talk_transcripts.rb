class AddLanguageToTalkTranscripts < ActiveRecord::Migration[8.2]
  def up
    add_column :talk_transcripts, :language, :string

    execute <<~SQL
      UPDATE talk_transcripts
      SET language = COALESCE((SELECT language FROM talks WHERE talks.id = talk_transcripts.talk_id), 'en')
    SQL

    change_column_default :talk_transcripts, :language, from: nil, to: "en"
    change_column_null :talk_transcripts, :language, false

    add_index :talk_transcripts, [:talk_id, :language], unique: true
  end

  def down
    remove_index :talk_transcripts, [:talk_id, :language]
    remove_column :talk_transcripts, :language
  end
end
