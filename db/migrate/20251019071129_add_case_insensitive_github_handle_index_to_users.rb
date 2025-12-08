class AddCaseInsensitiveGitHubHandleIndexToUsers < ActiveRecord::Migration[8.1]
  def up
    User.transaction do
      User.find_by(github_handle: "bodacious")&.assign_canonical_user!(canonical_user: User.find_by(github_handle: "Bodacious")) if User.find_by(github_handle: "Bodacious")
      User.find_by(github_handle: "joschkaschulz")&.assign_canonical_user!(canonical_user: User.find_by(github_handle: "JoschkaSchulz")) if User.find_by(github_handle: "JoschkaSchulz")
      User.find_by(github_handle: "kyfast")&.assign_canonical_user!(canonical_user: User.find_by(github_handle: "KyFaSt")) if User.find_by(github_handle: "KyFaSt")
      User.find_by(github_handle: "nabeelahy")&.assign_canonical_user!(canonical_user: User.find_by(github_handle: "NabeelahY")) if User.find_by(github_handle: "NabeelahY")
      User.find_by(github_handle: "ryanbrushett")&.assign_canonical_user!(canonical_user: User.find_by(github_handle: "RyanBrushett")) if User.find_by(github_handle: "RyanBrushett")
      User.find_by(github_handle: "thomascountz")&.assign_canonical_user!(canonical_user: User.find_by(github_handle: "Thomascountz")) if User.find_by(github_handle: "Thomascountz")
      User.find_by(github_handle: "tripple-a")&.assign_canonical_user!(canonical_user: User.find_by(github_handle: "Tripple-A")) if User.find_by(github_handle: "Tripple-A")
      User.find_by(github_handle: "winslett")&.assign_canonical_user!(canonical_user: User.find_by(github_handle: "Winslett")) if User.find_by(github_handle: "Winslett")
    end
    # Now add the case-insensitive unique index
    add_index :users, "lower(github_handle)", name: "index_users_on_lower_github_handle",
      unique: true, where: "github_handle IS NOT NULL AND github_handle != ''"
    remove_index :users, name: "index_users_on_github_handle"
  end

  def down
    remove_index :users, name: "index_users_on_lower_github_handle"
  end
end
