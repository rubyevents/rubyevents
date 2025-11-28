class CreateUsersSearchIndex < ActiveRecord::Migration[8.0]
  def change
    # Create the virtual FTS5 table for users
    create_virtual_table "users_search_index", "fts5", ["name", "github_handle", "tokenize = porter"]

    up_only do
      User.reindex_all
    end
  end
end
