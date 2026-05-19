class AddLevelToSponsors < ActiveRecord::Migration[8.2]
  def change
    add_column :sponsors, :level, :integer
  end
end
