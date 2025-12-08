# == Schema Information
#
# Table name: aliases
# Database name: primary
#
#  id             :integer          not null, primary key
#  aliasable_type :string           not null, indexed => [aliasable_id], uniquely indexed => [name], uniquely indexed => [slug]
#  name           :string           not null, uniquely indexed => [aliasable_type]
#  slug           :string           uniquely indexed => [aliasable_type]
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  aliasable_id   :integer          not null, indexed => [aliasable_type]
#
# Indexes
#
#  index_aliases_on_aliasable                (aliasable_type,aliasable_id)
#  index_aliases_on_aliasable_type_and_name  (aliasable_type,name) UNIQUE
#  index_aliases_on_aliasable_type_and_slug  (aliasable_type,slug) UNIQUE
#
class Alias < ApplicationRecord
  belongs_to :aliasable, polymorphic: true

  validates :name, presence: true, uniqueness: {scope: :aliasable_type}
  validates :slug, uniqueness: {scope: :aliasable_type}, allow_blank: true

  after_save_commit :reindex_aliasable
  after_destroy_commit :reindex_aliasable

  private

  def reindex_aliasable
    aliasable.reindex if aliasable.respond_to?(:reindex)
  end
end
