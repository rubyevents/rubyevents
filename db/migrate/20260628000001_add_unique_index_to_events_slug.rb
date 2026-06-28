class AddUniqueIndexToEventsSlug < ActiveRecord::Migration[8.2]
  def change
    remove_index :events, :slug, name: "index_events_on_slug"
    add_index :events, :slug, unique: true, name: "index_events_on_slug"
  end
end
