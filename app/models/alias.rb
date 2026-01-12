# == Schema Information
#
# Table name: aliases
# Database name: primary
#
#  id             :integer          not null, primary key
#  aliasable_type :string           not null, indexed => [aliasable_id], uniquely indexed => [name]
#  name           :string           not null, uniquely indexed => [aliasable_type]
#  slug           :string           indexed
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  aliasable_id   :integer          not null, indexed => [aliasable_type]
#
# Indexes
#
#  index_aliases_on_aliasable                (aliasable_type,aliasable_id)
#  index_aliases_on_aliasable_type_and_name  (aliasable_type,name) UNIQUE
#  index_aliases_on_slug                     (slug)
#
class Alias < ApplicationRecord
  belongs_to :aliasable, polymorphic: true

  validates :name, presence: true, uniqueness: {scope: :aliasable_type}
  validate :slug_globally_unique_except_same_aliasable

  after_save_commit :reindex
  after_destroy_commit :reindex

  private

  def slug_globally_unique_except_same_aliasable
    return if slug.blank?

    conflicting = self.class.where(slug: slug).where.not(aliasable_type: aliasable_type, aliasable_id: aliasable_id)
    conflicting = conflicting.where.not(id: id) if persisted?

    errors.add(:slug, :taken) if conflicting.exists?
  end

  def reindex
    return if Search::Backend.skip_indexing

    Search::Backend.index(aliasable)
  end
end
