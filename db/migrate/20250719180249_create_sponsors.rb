class CreateSponsors < ActiveRecord::Migration[8.0]
  def change
    create_table :sponsors do |t|
      t.string :name
      t.string :website
      t.string :logo_url
      t.text :description

      t.timestamps
    end
  end
end
