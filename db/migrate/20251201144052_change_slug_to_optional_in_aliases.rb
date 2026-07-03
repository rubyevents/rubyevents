class ChangeSlugToOptionalInAliases < ActiveRecord::Migration[8.1]
  def change
    change_column_null :aliases, :slug, true
  end
end
