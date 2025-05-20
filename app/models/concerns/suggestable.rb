module Suggestable
  extend ActiveSupport::Concern

  included do
    has_many :suggestions, as: :suggestable, dependent: :destroy
  end

  # NOTE: validate before saving
  def create_suggestion_from(params:, user: Current.user, new_record: false)
    params = select_differences_for(params) unless new_record

    suggestions.create(content: params, suggested_by_id: user&.id).tap do |suggestion|
      suggestion.approved!(approver: user) if managed_by?(user)
    end
  end

  private

  def managed_by?(visiting_user)
    # this should be overitten in the model where the concern is included
    raise NotImplementedError, "This method should be implemented in the model where the concern is included"
  end

  def select_differences_for(params)
    params.reject do |key, value|
      self[key] == value
    end
  end
end
