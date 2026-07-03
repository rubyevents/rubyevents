class RemoveCityColumnFromCities < ActiveRecord::Migration[8.2]
  def change
    remove_index :cities, [:country_code, :city]
    remove_column :cities, :city, :string
    add_index :cities, [:name, :country_code, :state_code]
  end
end
