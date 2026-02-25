class MigrateCanonicalUsersToAliases < ActiveRecord::Migration[8.1]
  def up
    User.where.not(canonical_id: nil).find_each do |user|
      next if user.name.blank?
      next unless user.canonical.present?
      next if user.slug.blank?

      Alias.find_or_create_by!(
        aliasable_type: "User",
        aliasable_id: user.canonical_id,
        name: user.name,
        slug: user.slug
      )

      user.update_column(:marked_for_deletion, true)

      puts "Created alias '#{user.name}' (slug: #{user.slug}) for canonical user #{user.canonical.name}"
    end
  end

  def down
    User.where(marked_for_deletion: true).update_all(marked_for_deletion: false)
    Alias.where(aliasable_type: "User").delete_all
  end
end
