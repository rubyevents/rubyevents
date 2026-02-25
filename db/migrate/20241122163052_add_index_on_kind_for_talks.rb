class AddIndexOnKindForTalks < ActiveRecord::Migration[8.0]
  def change
    add_index :talks, :kind
  end
end
