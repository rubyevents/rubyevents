class ChangeAliasesSlugIndex < ActiveRecord::Migration[8.2]
  def change
    remove_index :aliases, name: :index_aliases_on_aliasable_type_and_slug
    add_index :aliases, :slug
  end
end
