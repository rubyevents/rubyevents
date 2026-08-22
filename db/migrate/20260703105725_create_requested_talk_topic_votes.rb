class CreateRequestedTalkTopicVotes < ActiveRecord::Migration[8.2]
  def change
    create_table :requested_talk_topic_votes do |t|
      t.references :requested_talk_topic, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true

      t.timestamps
    end

    add_index :requested_talk_topic_votes,
      [:requested_talk_topic_id, :user_id],
      unique: true
  end
end
