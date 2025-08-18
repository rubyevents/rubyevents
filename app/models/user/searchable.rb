module User::Searchable
  extend ActiveSupport::Concern

  included do
    has_one :index, foreign_key: :rowid, inverse_of: :user, dependent: :destroy, class_name: "User::Index"

    scope :ft_search, ->(query) { select("users.*").joins(:index).merge(User::Index.search(query)) }

    scope :with_snippets, ->(**options) do
      select("users.*").merge(User::Index.snippets(**options))
    end

    scope :ranked, -> do
      select("users.*,
          bm25(users_search_index, 2, 1) AS combined_score")
        .order(combined_score: :asc)
    end

    after_save_commit :reindex
  end

  class_methods do
    def reindex_all
      includes(:index).find_each(&:reindex)
    end
  end

  def name_with_snippet
    try(:name_snippet) || name
  end

  def index
    super || build_index
  end
  delegate :reindex, to: :index
end
