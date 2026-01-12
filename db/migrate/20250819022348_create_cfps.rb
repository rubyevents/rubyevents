class CreateCfps < ActiveRecord::Migration[8.1]
  def change
    create_table :cfps do |t|
      t.string :name
      t.string :link
      t.date :open_date
      t.date :close_date
      t.references :event, null: false, foreign_key: true

      t.timestamps
    end
  end
end
