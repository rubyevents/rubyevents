class AddRubyFocusedToEvents < ActiveRecord::Migration[8.2]
  def change
    add_column :events, :ruby_focused, :boolean, default: true, null: false
  end
end
