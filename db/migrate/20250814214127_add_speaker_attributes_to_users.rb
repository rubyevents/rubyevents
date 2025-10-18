class AddSpeakerAttributesToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :bio, :text, default: "", null: false
    add_column :users, :website, :string, default: "", null: false
    add_column :users, :slug, :string, default: "", null: false
    add_column :users, :twitter, :string, default: "", null: false
    add_column :users, :bsky, :string, default: "", null: false
    add_column :users, :mastodon, :string, default: "", null: false
    add_column :users, :linkedin, :string, default: "", null: false
    add_column :users, :speakerdeck, :string, default: "", null: false
    add_column :users, :pronouns, :string, default: "", null: false
    add_column :users, :pronouns_type, :string, default: "not_specified", null: false
    add_column :users, :talks_count, :integer, default: 0, null: false
    add_column :users, :canonical_id, :integer
    add_column :users, :bsky_metadata, :json, default: {}, null: false
    add_column :users, :github_metadata, :json, default: {}, null: false

    # Add indexes similar to speakers table
    add_index :users, :slug, unique: true, where: "slug IS NOT NULL AND slug != ''"
    add_index :users, :canonical_id
    add_index :users, :name, where: "name IS NOT NULL AND name != ''"
  end
end
