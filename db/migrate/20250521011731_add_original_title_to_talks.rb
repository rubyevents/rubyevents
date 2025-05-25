class AddOriginalTitleToTalks < ActiveRecord::Migration[8.0]
  def change
    add_column :talks, :original_title, :string, default: "", null: false
  end
end
