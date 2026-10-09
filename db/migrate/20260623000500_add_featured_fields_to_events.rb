class AddFeaturedFieldsToEvents < ActiveRecord::Migration[8.2]
  def change
    add_column :events, :featured_background, :string
    add_column :events, :featured_color, :string
    add_column :events, :banner_background, :string
    add_column :events, :home_sort_date, :date
  end
end
