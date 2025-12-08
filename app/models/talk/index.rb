class Talk::Index < ApplicationRecord
  self.table_name = :talks_search_index

  include ActiveRecord::SQLite::Index # Depends on `table_name` being assigned.

  class_attribute :index_columns, default: {title: 0, summary: 1, speaker_names: 2, event_names: 3}

  belongs_to :talk, foreign_key: :rowid

  def self.search(query)
    query = remove_invalid_search_characters(query) || "" # remove non-word characters
    query = remove_unbalanced_quotes(query)
    query = query.split.map { |word| "#{word}*" }.join(" ") # wildcard search
    query = query.strip.presence

    return all if query.blank?

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
    update! id: talk.id, title: talk.title, summary: talk.summary, speaker_names: talk.speaker_names, event_names: talk.event_names
  end

  def self.remove_invalid_search_characters(query)
    query.gsub(/[^\w"]/, " ")
  end

  def self.remove_unbalanced_quotes(query)
    if query.count("\"").even?
      query
    else
      query.tr("\"", " ")
    end
  end
end
