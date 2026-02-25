class CreateTalkTranscript < ActiveRecord::Migration[8.0]
  def change
    create_table :talk_transcripts do |t|
      t.references :talk, null: false, foreign_key: true
      t.text :raw_transcript
      t.text :enhanced_transcript
      t.timestamps
    end

    # Move existing data
    execute <<-SQL
        INSERT INTO talk_transcripts (talk_id, raw_transcript, enhanced_transcript, created_at, updated_at)
        SELECT id, raw_transcript, enhanced_transcript, created_at, updated_at
        FROM talks
    SQL

    remove_column :talks, :raw_transcript
    remove_column :talks, :enhanced_transcript
  end
end
