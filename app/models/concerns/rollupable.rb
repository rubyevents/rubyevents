module Rollupable
  extend ActiveSupport::Concern

  class_methods do
    attr_reader :rollup_column

    def rollup_default_column(column)
      @rollup_column = column
    end

    def rollup(*args, **options, &block)
      Rollup::Aggregator.new(self).rollup(*args, **options, &block)
      nil
    end
  end
end
