class AddSlidesUrlToTalks < ActiveRecord::Migration[7.2]
  def change
    add_column :talks, :slides_url, :string
  end
end
