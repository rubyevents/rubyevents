module ActiveRecord::SQLite::Index
  extend ActiveSupport::Concern

  included do
    self.ignored_columns = [table_name.to_sym, :rank] # Rails parses our virtual table with these extra non-attributes.

    attribute :rowid, :integer
    alias_attribute :id, :rowid
    self.primary_key = :rowid

    # Active Record doesn't pick up the `rowid` primary key column.
    # So we have have explicitly declare this scope to have `rowid` populated in the result set.
    default_scope { select("#{table_name}.rowid, #{table_name}.*") }
  end

  private

  def attributes_for_create(attribute_names)
    # Prevent `super` filtering out the primary key because it isn't in `self.class.column_names`.
    [self.class.primary_key, *super]
  end
end
