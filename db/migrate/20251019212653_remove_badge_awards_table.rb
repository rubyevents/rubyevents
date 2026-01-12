class RemoveBadgeAwardsTable < ActiveRecord::Migration[8.1]
  def change
    # this was added in an unmerged PR, so we need to remove it
    drop_table :badge_awards, if_exists: true
  end
end
