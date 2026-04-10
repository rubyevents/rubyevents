class CreateFeaturedCities < ActiveRecord::Migration[8.2]
  def change
    create_table :featured_cities do |t|
      t.string :name, null: false
      t.string :slug, null: false
      t.string :city, null: false
      t.string :state_code
      t.string :country_code, null: false
      t.decimal :latitude, precision: 10, scale: 6
      t.decimal :longitude, precision: 10, scale: 6

      t.timestamps
    end
    add_index :featured_cities, :slug, unique: true
    add_index :featured_cities, [:country_code, :city]
  end
end
