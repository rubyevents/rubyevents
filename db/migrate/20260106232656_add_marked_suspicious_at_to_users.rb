class AddMarkedSuspiciousAtToUsers < ActiveRecord::Migration[8.2]
  def change
    add_column :users, :suspicion_marked_at, :datetime
    add_column :users, :suspicion_cleared_at, :datetime
  end
end
