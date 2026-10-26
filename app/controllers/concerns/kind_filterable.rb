# frozen_string_literal: true

# Filters event lists by kind, like only conferences or only meetups, with `?kind=meetup`.
module KindFilterable
  extend ActiveSupport::Concern

  included do
    helper_method :selected_kind
  end

  private

  def selected_kind
    return @selected_kind if defined?(@selected_kind)

    @selected_kind = params[:kind].presence_in(Event.kinds.keys)
  end

  def filter_by_kind(scope)
    return scope if selected_kind.nil?

    scope.where(kind: selected_kind)
  end

  def kind_counts(scope)
    scope.unscope(:order, :limit, :includes).group(:kind).count.sort_by { |kind, _count| Event.kinds.keys.index(kind) }.to_h
  end
end
