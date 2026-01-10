class AddGeocodeMetadataToEvents < ActiveRecord::Migration[8.2]
  def change
    add_column :events, :geocode_metadata, :json, default: {}, null: false
  end
end
