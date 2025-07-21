class AddTierToEventSponsors < ActiveRecord::Migration[8.0]
  def change
    add_column :event_sponsors, :tier, :string
  end
end
