# frozen_string_literal: true

module SpotlightSearch
  extend ActiveSupport::Concern

  included do
    helper_method :search_backend
  end

  private

  def search_backend_class
    @search_backend_class ||= begin
      preferred = Rails.env.development? ? params[:search_backend] : nil
      ::SearchBackend.resolve(preferred)
    end
  end

  def search_backend
    return nil unless search_query.present?
    search_backend_class.name
  end
end
