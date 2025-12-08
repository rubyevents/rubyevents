# Guardfile for watching YAML files in data/ and auto-importing them

require_relative "lib/guard/data_import"

guard :data_import, wait_for_delay: 2 do
  watch(%r{^data/speakers\.yml$})
  watch(%r{^data/topics\.yml$})
  watch(%r{^data/[^/]+/series\.yml$})
  watch(%r{^data/[^/]+/[^/]+/event\.yml$})
  watch(%r{^data/[^/]+/[^/]+/videos\.yml$})
  watch(%r{^data/[^/]+/[^/]+/cfp\.yml$})
  watch(%r{^data/[^/]+/[^/]+/sponsors\.yml$})
  watch(%r{^data/[^/]+/[^/]+/schedule\.yml$})
end
