# frozen_string_literal: true

class AddPerfIndexes < ActiveRecord::Migration[6.1]
  # Use `algorithm: :concurrently` for large tables. This requires running
  # outside of a transaction, so we disable the migration transaction.
  disable_ddl_transaction!

  def up
    add_index :talks, :event_id, algorithm: :concurrently unless index_exists?(:talks, :event_id)
    add_index :talks, :date, algorithm: :concurrently unless index_exists?(:talks, :date)
    add_index :talks, :published_at, algorithm: :concurrently unless index_exists?(:talks, :published_at)

    add_index :talk_topics, :topic_id, algorithm: :concurrently unless index_exists?(:talk_topics, :topic_id)

    add_index :user_talks, :user_id, algorithm: :concurrently unless index_exists?(:user_talks, :user_id)
    add_index :user_talks, :talk_id, algorithm: :concurrently unless index_exists?(:user_talks, :talk_id)

    add_index :cfps, :close_date, algorithm: :concurrently unless index_exists?(:cfps, :close_date)

    add_index :events, :country_code, algorithm: :concurrently unless index_exists?(:events, :country_code)
  end

  def down
    remove_index :talks, :event_id if index_exists?(:talks, :event_id)
    remove_index :talks, :date if index_exists?(:talks, :date)
    remove_index :talks, :published_at if index_exists?(:talks, :published_at)

    remove_index :talk_topics, :topic_id if index_exists?(:talk_topics, :topic_id)

    remove_index :user_talks, :user_id if index_exists?(:user_talks, :user_id)
    remove_index :user_talks, :talk_id if index_exists?(:user_talks, :talk_id)

    remove_index :cfps, :close_date if index_exists?(:cfps, :close_date)

    remove_index :events, :country_code if index_exists?(:events, :country_code)
  end
end
