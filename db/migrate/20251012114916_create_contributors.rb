class CreateContributors < ActiveRecord::Migration[8.1]
  def change
    create_table :contributors do |t|
      t.string :login, null: false
      t.string :name
      t.string :avatar_url
      t.string :html_url
      t.references :user, foreign_key: true

      t.timestamps
    end

    add_index :contributors, :login, unique: true
  end
end
