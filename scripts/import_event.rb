series_slug = ARGV[0]

if series_slug.blank?
  series_slugs = Static::EventSeries.all.map(&:slug).sort

  series_slug = IO.popen(["fzy"], "r+") do |fzy|
    fzy.puts(series_slugs.join("\n"))
    fzy.close_write
    fzy.gets&.strip
  end

  if series_slug.blank?
    puts "No series selected"
    exit 1
  end
end

static_series = Static::EventSeries.find_by_slug(series_slug)

raise "Event series '#{series_slug}' not found in static data" if static_series.nil?

static_series.import!
