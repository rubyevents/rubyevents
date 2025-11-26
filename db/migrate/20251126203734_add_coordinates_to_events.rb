class AddCoordinatesToEvents < ActiveRecord::Migration[8.1]
  def change
    add_column :events, :lng, :decimal, precision: 10, scale: 7
    add_column :events, :lat, :decimal, precision: 10, scale: 7
  end
end
