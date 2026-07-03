class RenameFeaturedCitiesToCities < ActiveRecord::Migration[8.2]
  def change
    rename_table :featured_cities, :cities

    add_column :cities, :featured, :boolean, default: false, null: false
    add_column :cities, :geocode_metadata, :json, default: {}, null: false

    reversible do |dir|
      dir.up do
        execute "UPDATE cities SET featured = true"
      end
    end

    add_index :cities, :featured
  end
end
