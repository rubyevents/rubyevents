class AddFeedbackEnabledToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :feedback_enabled, :boolean, default: true, null: false
  end
end
