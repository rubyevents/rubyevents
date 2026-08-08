# frozen_string_literal: true

# Backport of https://github.com/ruby/error_highlight/pull/80
# Remove once the fix ships with Ruby.

if defined?(ErrorHighlight::CoreExt)
  module ErrorHighlightNilBacktraceLocationsFix
    private def generate_snippet
      return "" if backtrace_locations.nil?

      super
    end
  end

  TypeError.prepend(ErrorHighlightNilBacktraceLocationsFix)
  ArgumentError.prepend(ErrorHighlightNilBacktraceLocationsFix)
end
