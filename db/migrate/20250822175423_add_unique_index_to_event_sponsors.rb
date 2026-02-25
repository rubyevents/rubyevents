class AddUniqueIndexToEventSponsors < ActiveRecord::Migration[8.1]
  def up
    add_index :event_sponsors, [:event_id, :sponsor_id, :tier],
      unique: true,
      name: "index_event_sponsors_on_event_sponsor_tier_unique"
  end

  def down
    remove_index :event_sponsors, name: "index_event_sponsors_on_event_sponsor_tier_unique"
  end
end
