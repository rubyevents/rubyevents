# frozen_string_literal: true

module User::SQLiteFTSSearchable
  extend ActiveSupport::Concern

  included do
    has_one :fts_index, foreign_key: :rowid, inverse_of: :user, dependent: :destroy, class_name: "User::Index"

    scope :ft_search, ->(query) { select("users.*").joins(:fts_index).merge(User::Index.search(query)) }

    scope :with_snippets, ->(**options) do
      select("users.*").merge(User::Index.snippets(**options))
    end

    scope :ranked, -> do
      select("users.*,
          bm25(users_search_index, 2, 1) AS combined_score")
        .order(combined_score: :asc)
    end

    after_save_commit :reindex_fts
  end

  def name_with_snippet
    try(:name_snippet) || name
  end

  def fts_index
    super || build_fts_index
  end

  def reindex_fts
    return if Search::Backend.skip_indexing

    fts_index.reindex
  end
end
