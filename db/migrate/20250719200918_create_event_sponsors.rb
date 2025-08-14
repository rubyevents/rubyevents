class CreateEventSponsors < ActiveRecord::Migration[8.0]
  def change
    create_table :event_sponsors do |t|
      t.references :event, null: false, foreign_key: true
      t.references :sponsor, null: false, foreign_key: true

      t.timestamps
    end
  end
end
