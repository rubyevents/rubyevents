class RenameStateToStateCodeOnEventsAndUsers < ActiveRecord::Migration[8.2]
  def change
    rename_column :events, :state, :state_code
    rename_column :users, :state, :state_code
  end
end
