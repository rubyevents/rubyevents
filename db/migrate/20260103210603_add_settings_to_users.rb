class AddSettingsToUsers < ActiveRecord::Migration[8.2]
  def up
    add_column :users, :settings, :json, null: false, default: {}

    execute <<-SQL
      UPDATE users
      SET settings = json_object(
        'feedback_enabled', feedback_enabled,
        'wrapped_public', wrapped_public
      )
    SQL

    remove_column :users, :feedback_enabled
    remove_column :users, :wrapped_public
  end

  def down
    add_column :users, :feedback_enabled, :boolean, null: false, default: true
    add_column :users, :wrapped_public, :boolean, null: false, default: false

    execute <<-SQL
      UPDATE users
      SET feedback_enabled = COALESCE(json_extract(settings, '$.feedback_enabled'), 1),
          wrapped_public = COALESCE(json_extract(settings, '$.wrapped_public'), 0)
    SQL

    remove_column :users, :settings
  end
end
