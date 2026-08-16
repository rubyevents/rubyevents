class AddTranslatedToTalkTranscripts < ActiveRecord::Migration[8.2]
  def change
    add_column :talk_transcripts, :translated, :boolean, default: false, null: false
  end
end
