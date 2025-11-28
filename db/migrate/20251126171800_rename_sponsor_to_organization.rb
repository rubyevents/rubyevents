class RenameSponsorToOrganization < ActiveRecord::Migration[8.1]
  def change
    rename_table :sponsors, :organizations

    add_column :organizations, :kind, :integer, default: 0, null: false
    add_index :organizations, :kind
    rename_index :organizations, :index_sponsors_on_slug, :index_organizations_on_slug

    rename_column :event_sponsors, :sponsor_id, :organization_id
    rename_index :event_sponsors, :index_event_sponsors_on_sponsor_id, :index_event_sponsors_on_organization_id
    remove_index :event_sponsors, name: :index_event_sponsors_on_event_sponsor_tier_unique

    add_index :event_sponsors, [:event_id, :organization_id, :tier], unique: true, name: :index_event_sponsors_on_event_organization_tier_unique

    execute <<-SQL
      UPDATE aliases
      SET aliasable_type = 'Organization'
      WHERE aliasable_type = 'Sponsor'
    SQL

    execute <<-SQL
      UPDATE event_involvements
      SET involvementable_type = 'Organization'
      WHERE involvementable_type = 'Sponsor'
    SQL
  end
end
