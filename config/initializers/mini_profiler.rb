if defined?(Rack::MiniProfiler)
  Rack::MiniProfiler.config.skip_paths ||= []
  Rack::MiniProfiler.config.skip_paths << %r{\A/talks/[^/]+/thumbnail(\.\w+)?\z}
end
