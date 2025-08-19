class User::Index < ApplicationRecord
  self.table_name = :users_search_index

  include ActiveRecord::SQLite::Index # Depends on `table_name` being assigned.
  class_attribute :index_columns, default: {name: 0, github_handle: 1}

  belongs_to :user, foreign_key: :rowid

  def self.search(query)
    query = query&.gsub(/[^[:word:]]/, " ") || "" # remove non-word characters
    query = query.split.map { |word| "#{word}*" }.join(" ") # wildcard search
    where("#{table_name} match ?", query)
  end

  def self.snippets(**)
    index_columns.each_key.reduce(all) { |relation, column| relation.snippet(column, **) }
  end

  def self.snippet(column, tag: "mark", omission: "…", limit: 32)
    offset = index_columns.fetch(column)
    select("snippet(#{table_name}, #{offset}, '<#{tag}>', '</#{tag}>', '#{omission}', #{limit}) AS #{column}_snippet")
  end

  def reindex
    update! id: user.id, name: user.name, github_handle: user.github_handle
  end
end
