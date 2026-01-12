class AddSlugToSponsors < ActiveRecord::Migration[8.0]
  def change
    add_column :sponsors, :slug, :string
    add_index :sponsors, :slug
  end
end
