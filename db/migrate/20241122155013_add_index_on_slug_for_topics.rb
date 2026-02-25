class AddIndexOnSlugForTopics < ActiveRecord::Migration[8.0]
  def change
    change_column_default :topics, :slug, from: nil, to: ""
    add_index :topics, :slug
  end
end
