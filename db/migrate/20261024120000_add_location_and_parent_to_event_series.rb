class AddLocationAndParentToEventSeries < ActiveRecord::Migration[8.2]
  def change
    add_reference :event_series, :parent, foreign_key: {to_table: :event_series}, null: true

    add_column :event_series, :location, :string, default: "", null: false
    add_column :event_series, :city, :string
    add_column :event_series, :state_code, :string
    add_column :event_series, :country_code, :string
    add_column :event_series, :latitude, :decimal, precision: 10, scale: 6
    add_column :event_series, :longitude, :decimal, precision: 10, scale: 6

    add_index :event_series, :country_code
  end
end
