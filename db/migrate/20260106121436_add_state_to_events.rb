class AddStateToEvents < ActiveRecord::Migration[8.2]
  def change
    add_column :events, :state, :string
    add_index :events, [:country_code, :state]
  end
end
