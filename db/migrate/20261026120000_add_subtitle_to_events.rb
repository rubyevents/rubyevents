class AddSubtitleToEvents < ActiveRecord::Migration[8.2]
  def change
    add_column :events, :subtitle, :string, default: "", null: false
  end
end
