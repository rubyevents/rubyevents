module Talk::Searchable
  extend ActiveSupport::Concern

  DATE_WEIGHT = 0.000000001

  included do
    has_one :index, foreign_key: :rowid, inverse_of: :talk, dependent: :destroy

    scope :ft_search, ->(query) { select("talks.*").joins(:index).merge(Talk::Index.search(query)) }

    scope :with_snippets, ->(**options) do
      select("talks.*").merge(Talk::Index.snippets(**options))
    end

    scope :ranked, -> do
      select("talks.*,
          bm25(talks_search_index, 10.0, 1.0, 5.0) +
          (strftime('%s', 'now') - strftime('%s', talks.date)) * #{DATE_WEIGHT} AS combined_score")
        .order(combined_score: :asc)
    end

    # Filter on FTS table directly for better performance with search
    # This allows FTS5 to optimize the query when combined with MATCH
    scope :ft_watchable, -> do
      joins(:index).where("talks_search_index.video_provider IN (?)", Talk::WATCHABLE_PROVIDERS)
    end

    after_save_commit :reindex
  end

  class_methods do
    def reindex_all
      includes(:index).find_each(&:reindex)
    end
  end

  def title_with_snippet
    try(:title_snippet) || title
  end

  def index
    super || build_index
  end
  delegate :reindex, to: :index
end
