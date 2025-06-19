# frozen_string_literal: true

class AddDatePrecisionToEvents < ActiveRecord::Migration[8.0]
  def change
    add_column :events, :date_precision, :string, null: false, default: "day"
  end
end
