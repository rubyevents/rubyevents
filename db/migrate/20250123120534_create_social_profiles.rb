class CreateSocialProfiles < ActiveRecord::Migration[8.0]
  def change
    create_table :social_profiles do |t|
      t.string :provider, null: false
      t.string :value, null: false
      t.belongs_to :sociable, polymorphic: true, null: false
      t.timestamps
    end

    reversible do |dir|
      dir.up do
        execute <<-SQL
          INSERT INTO social_profiles (sociable_id, sociable_type, value, provider, created_at, updated_at)
            SELECT id AS sociable_id, 'Speaker' AS sociable_type, twitter, 'twitter' AS provider, DATETIME('now') AS created_at, DATETIME('now') AS updated_at  FROM speakers WHERE twitter != ''
          UNION ALL
            SELECT id AS sociable_id, 'Speaker' AS sociable_type, website, 'website' AS provider, DATETIME('now') AS created_at, DATETIME('now') AS updated_at  FROM speakers WHERE website != ''
          UNION ALL
            SELECT id AS sociable_id, 'Speaker' AS sociable_type, speakerdeck, 'speaker_deck' AS provider, DATETIME('now') AS created_at, DATETIME('now') AS updated_at  FROM speakers WHERE speakerdeck != ''
          UNION ALL
            SELECT id AS sociable_id, 'Speaker' AS sociable_type, mastodon, 'mastodon' AS provider, DATETIME('now') AS created_at, DATETIME('now') AS updated_at  FROM speakers WHERE mastodon != ''
          UNION ALL
            SELECT id AS sociable_id, 'Speaker' AS sociable_type, bsky, 'bsky' AS provider, DATETIME('now') AS created_at, DATETIME('now') AS updated_at  FROM speakers WHERE bsky != ''
          UNION ALL
            SELECT id AS sociable_id, 'Speaker' AS sociable_type, linkedin, 'linkedin' AS provider, DATETIME('now') AS created_at, DATETIME('now') AS updated_at  FROM speakers WHERE linkedin != ''
        SQL

        execute <<-SQL
          INSERT INTO social_profiles (sociable_id, sociable_type, value, provider, created_at, updated_at)
            SELECT id AS sociable_id, 'Event' AS sociable_type, website, 'website' AS provider, DATETIME('now') AS created_at, DATETIME('now') AS updated_at  FROM events WHERE website != ''
        SQL

        execute <<-SQL
          INSERT INTO social_profiles (sociable_id, sociable_type, value, provider, created_at, updated_at)
            SELECT id AS sociable_id, 'Organisation' AS sociable_type, website, 'website' AS provider, DATETIME('now') AS created_at, DATETIME('now') AS updated_at  FROM organisations WHERE website != ''
          UNION ALL
            SELECT id AS sociable_id, 'Organisation' AS sociable_type, twitter, 'twitter' AS provider, DATETIME('now') AS created_at, DATETIME('now') AS updated_at  FROM organisations WHERE twitter != ''
        SQL
      end
    end
  end
end
