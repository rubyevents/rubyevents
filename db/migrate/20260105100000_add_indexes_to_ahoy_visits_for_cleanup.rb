class AddIndexesToAhoyVisitsForCleanup < ActiveRecord::Migration[8.0]
  def change
    # Composite index for the suspicious IP query
    # Covers: WHERE started_at > X GROUP BY ip
    add_index :ahoy_visits, [:started_at, :ip],
      name: "index_ahoy_visits_on_started_at_and_ip",
      if_not_exists: true

    # Index on ip for the batch deletion queries
    add_index :ahoy_visits, :ip,
      name: "index_ahoy_visits_on_ip",
      if_not_exists: true
  end
end

