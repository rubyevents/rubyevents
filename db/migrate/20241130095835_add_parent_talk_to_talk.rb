class AddParentTalkToTalk < ActiveRecord::Migration[8.0]
  def change
    add_reference :talks, :parent_talk, foreign_key: {to_table: :talks}, null: true
    add_column :talks, :meta_talk, :boolean, default: false, null: false
    add_column :talks, :start_seconds, :integer, null: true
    add_column :talks, :end_seconds, :integer, null: true
  end
end
