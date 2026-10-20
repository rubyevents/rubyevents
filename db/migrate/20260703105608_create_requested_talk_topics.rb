class CreateRequestedTalkTopics < ActiveRecord::Migration[8.2]
  def change
    create_table :requested_talk_topics do |t|
      t.string :title, null: false
      t.text :description
      t.string :status, null: false, default: "open"
      t.integer :votes_count, null: false, default: 0

      t.references :user, null: false, foreign_key: true

      t.timestamps
    end

    add_index :requested_talk_topics, :status
    add_index :requested_talk_topics, :votes_count
  end
end
