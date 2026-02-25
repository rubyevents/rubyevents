class AddDurationToTalk < ActiveRecord::Migration[8.0]
  def change
    add_column :talks, :duration_in_seconds, :integer
  end
end
