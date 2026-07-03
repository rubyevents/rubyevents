class CreateAliases < ActiveRecord::Migration[8.1]
  def change
    create_table :aliases do |t|
      t.references :aliasable, polymorphic: true, null: false
      t.string :name, null: false
      t.string :slug, null: false

      t.timestamps
    end

    add_index :aliases, [:aliasable_type, :name], unique: true, name: "index_aliases_on_aliasable_type_and_name"
    add_index :aliases, [:aliasable_type, :slug], unique: true, name: "index_aliases_on_aliasable_type_and_slug"
  end
end
