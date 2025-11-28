class AddMainLocationToSponsors < ActiveRecord::Migration[8.0]
  def change
    add_column :sponsors, :main_location, :string
  end
end
