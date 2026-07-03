class CreateTopicGems < ActiveRecord::Migration[8.2]
  def change
    create_table :topic_gems do |t|
      t.references :topic, null: false, foreign_key: true
      t.string :gem_name, null: false

      t.timestamps
    end

    add_index :topic_gems, [:topic_id, :gem_name], unique: true
  end
end
