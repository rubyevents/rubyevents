class AddGeocodingToUsers < ActiveRecord::Migration[8.2]
  def change
    add_column :users, :city, :string
    add_column :users, :state, :string
    add_column :users, :country_code, :string
    add_column :users, :latitude, :decimal, precision: 10, scale: 6
    add_column :users, :longitude, :decimal, precision: 10, scale: 6
    add_column :users, :geocode_metadata, :json, default: {}, null: false
  end
end
