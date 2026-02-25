class AddIndexVideoProviderToTalk < ActiveRecord::Migration[8.0]
  def change
    add_index :talks, [:video_provider, :date]
  end
end
