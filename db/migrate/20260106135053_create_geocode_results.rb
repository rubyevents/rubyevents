class CreateGeocodeResults < ActiveRecord::Migration[8.2]
  def change
    create_table :geocode_results do |t|
      t.string :query, null: false, index: {unique: true}
      t.text :response_body, null: false

      t.timestamps
    end
  end
end
