class AddBadgeToEventSponsors < ActiveRecord::Migration[8.0]
  def change
    add_column :event_sponsors, :badge, :string
  end
end
