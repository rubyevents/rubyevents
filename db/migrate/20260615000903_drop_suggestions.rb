class DropSuggestions < ActiveRecord::Migration[8.2]
  def up
    drop_table :suggestions
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
