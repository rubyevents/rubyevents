class RenameEventSponsorToSponsor < ActiveRecord::Migration[8.1]
  def change
    rename_table :event_sponsors, :sponsors

    rename_index :sponsors, :index_event_sponsors_on_event_id, :index_sponsors_on_event_id
    rename_index :sponsors, :index_event_sponsors_on_organization_id, :index_sponsors_on_organization_id
    rename_index :sponsors, :index_event_sponsors_on_event_organization_tier_unique, :index_sponsors_on_event_organization_tier_unique
  end
end
