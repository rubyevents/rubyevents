# Fetch upcoming meetup sessions for all local `kind: meetup` events.
#
# Requires `CLOUDFLARE_ACCOUNT_ID` and `CLOUDFLARE_API_KEY` environment variables. The API key must have been granted access to the Cloudflare Browser Rendering API.
#
# Workflow:
# - Scan `data/**/event.yml` for `kind: "meetup"` events and derive the meetup/website URL
#   (falling back to the parent `data/<series>/series.yml` when needed).
# - Use Cloudflare Browser Rendering + the LLM prompt to extract the next session
#   date/name/description/url from the meetup "upcoming events" page.
# - Append a new entry into the event's `videos.yml` for the next session date.
require "dotenv/load"
require "json"
require "net/http"
require "uri"
require "yaml"

DATA_ROOT = File.expand_path("../data", __dir__).freeze

def cloudflare_account_id
  ENV["CLOUDFLARE_ACCOUNT_ID"].to_s.strip
end

def resolve_meetup_url(event_yml, series_yml)
  [
    event_yml["meetup"],
    event_yml["website"],
    series_yml["meetup"],
    series_yml["website"]
  ].map { |candidate| candidate.to_s.strip }
    .find { |candidate| !candidate.empty? && candidate.downcase.include?("meetup.com") }
end

def local_meetups
  files = Dir.glob("#{DATA_ROOT}/**/event.yml")

  meetups = []
  seen = {}

  files.each do |path|
    y = YAML.load_file(path) || {}
    next unless y["kind"].to_s == "meetup"

    event_dir = File.dirname(path)
    series_path = File.join(File.dirname(event_dir), "series.yml")
    series_y = File.exist?(series_path) ? (YAML.load_file(series_path) || {}) : {}

    url = resolve_meetup_url(y, series_y)
    next if url.nil?

    title = y["title"].to_s.strip
    id = y["id"].to_s.strip

    org_slug = File.basename(File.dirname(event_dir))
    videos_path = File.join(event_dir, "videos.yml")

    key = [id, title, url]
    next if seen[key]
    seen[key] = true

    meetups << {
      title: title,
      id: id,
      url: url,
      org_slug: org_slug,
      videos_path: videos_path
    }
  end

  meetups.sort_by! { |m| [m[:title].downcase, m[:id]] }
end

def sanitize_token(api_key)
  api_key.to_s.strip
end

def slugify(str)
  str.to_s
    .downcase
    .strip
    .gsub(/[^a-z0-9]+/, "-")
    .squeeze("-")
    .sub(/\A-/, "")
    .sub(/-\z/, "")
end

def load_videos_yaml(videos_path)
  return [] unless File.exist?(videos_path)

  y = YAML.load_file(videos_path)
  return [] unless y.is_a?(Array)

  y
rescue => e
  warn "Failed to read videos.yml at #{videos_path}: #{e.message}"
  []
end

def append_videos_yaml_entry(videos_path, entry)
  content = File.exist?(videos_path) ? File.read(videos_path) : ""
  content = "---\n" if content.to_s.strip.empty?

  content << "\n" unless content.end_with?("\n")

  # YAML.dump([entry]) produces a full document; strip the header so it can be appended.
  entry_yaml = YAML.dump([entry])
  entry_yaml = entry_yaml.sub(/\A---\s*\n/, "")
  entry_yaml = entry_yaml.sub(/\n\z/, "")

  content << entry_yaml
  content << "\n" unless content.end_with?("\n")

  File.write(videos_path, content)
end

def maybe_append_next_meetup_to_videos(meetup:, extracted:)
  next_date = extracted["next_meetup_date"].to_s.strip
  return if next_date.empty?
  return if next_date.downcase == "unknown"

  videos_path = meetup[:videos_path]
  session_name = extracted["name"].to_s.strip
  session_url = extracted["url"].to_s.strip
  session_desc = extracted["description"].to_s.strip

  session_name = "" if session_name.downcase == "unknown"
  session_url = "" if session_url.downcase == "unknown"
  session_desc = "" if session_desc.downcase == "unknown"

  entries = load_videos_yaml(videos_path)
  if entries.any? { |e| e.is_a?(Hash) && e["date"].to_s.strip == next_date }
    puts "Found an existing event for #{meetup[:title]} on #{next_date}; skipping"
    return
  end

  organization = meetup[:org_slug].to_s.strip
  fallback_title = session_name.empty? ? next_date : session_name
  entry_id = slugify("#{organization}-#{fallback_title}")
  entry_id = slugify("#{organization}-#{next_date}") if entry_id.empty?

  description_parts = []
  description_parts << session_desc unless session_desc.empty?
  description_parts << session_url unless session_url.empty?

  description = description_parts.join("\n\n")
  description = session_url if description.empty? && !session_url.empty?

  entry = {
    "id" => entry_id,
    "title" => session_name,
    "date" => next_date,
    "video_id" => entry_id,
    "video_provider" => "scheduled",
    "description" => description,
    "talks" => []
  }

  append_videos_yaml_entry(videos_path, entry)
  puts "Wrote new entry into #{videos_path} for #{next_date}"
end

def normalize_meetup_url(raw_url)
  raw = raw_url.to_s.strip
  return "" if raw.empty?

  # Handle protocol-less URLs like `meetup.com/austinrb`
  raw =
    if raw.start_with?("//")
      "https:#{raw}"
    elsif raw.start_with?("meetup.com/")
      "https://www.#{raw}"
    elsif %r{\Ahttps?://}i.match?(raw)
      raw
    else
      "https://www.meetup.com/#{raw.sub(%r{\A/}, "")}"
    end

  uri = URI.parse(raw)
  return "" unless uri.host.to_s.downcase.include?("meetup.com")

  uri.scheme = "https"
  uri.host = "www.meetup.com"
  uri.query = nil

  path = uri.path.to_s
  # Normalize trailing slashes so we can reason about the last segment.
  path = path.sub(%r{/+\z}, "")
  path = "" if path == "/"

  segments = path.split("/").reject(&:empty?)
  # If the URL is just the host or malformed, skip normalization.
  return "" if segments.empty?

  last = segments.last.to_s.downcase
  if last != "events"
    segments << "events"
  end

  uri.path = "/#{segments.join("/")}/"
  uri.to_s
end

def fetch_next_meetup_via_cloudflare(meetup_url:, token:)
  account_id = cloudflare_account_id
  return {"success" => false, "error" => "CLOUDFLARE_ACCOUNT_ID is missing"} if account_id.empty?

  browser_json_url = "https://api.cloudflare.com/client/v4/accounts/#{account_id}/browser-rendering/json"
  uri = URI.parse(browser_json_url)

  prompt = <<~PROMPT
    You are given a webpage for upcoming events for a Ruby community meetup.

    Task:
    1) Find the NEXT upcoming meetup session date on the page. If there are multiple upcoming dates, choose the first one which is a Ruby Meetup.
    2) Extract the name of this specific session, e.g. "April 2026 Community Meetup".
    3) Extract the description of this specific session. If not possible, leave it as an empty string.
    4) Extract the URL of this specific session - typically in the form https://www.meetup.com/GROUPNAME/events/NUMERICID/

    Output requirements:
    - Return JSON that matches the provided schema.
    - next_meetup_date must be an ISO date string like "YYYY-MM-DD".
    - If you cannot confidently find an upcoming date, return "unknown" for all fields.
  PROMPT

  schema = {
    "type" => "object",
    "properties" => {
      "name" => {"type" => "string"},
      "url" => {"type" => "string"},
      "description" => {"type" => "string"},
      "next_meetup_date" => {"type" => "string"}
    },
    "required" => %w[name url description next_meetup_date]
  }

  payload = {
    "url" => meetup_url,
    "prompt" => prompt,
    "response_format" => {
      "type" => "json_schema",
      "schema" => schema
    },
    "gotoOptions" => {
      "waitUntil" => "networkidle0"
    }
  }

  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true

  req = Net::HTTP::Post.new(uri.request_uri)
  req["Authorization"] = "Bearer #{token}"
  req["Content-Type"] = "application/json"
  req.body = JSON.generate(payload)

  begin
    response_body = http.request(req).body
    JSON.parse(response_body)
  rescue => e
    body = nil
    if e.respond_to?(:response) && e.response
      begin
        body = e.response.body
      rescue
        body = nil
      end
    end

    if body && !body.to_s.strip.empty?
      begin
        JSON.parse(body)
      rescue
        {"success" => false, "error" => body.to_s}
      end
    else
      {"success" => false, "error" => e.message}
    end
  end
end

def fetch_next_meetups(limit: nil, offset: 0, verbose: false)
  api_key = ENV["CLOUDFLARE_API_KEY"].to_s.strip
  if api_key.empty?
    warn "CLOUDFLARE_API_KEY is missing"
    return []
  end

  token = sanitize_token(api_key)

  meetups = local_meetups
  offset = [offset.to_i, 0].max

  meetups = meetups.drop(offset)
  meetups = meetups.first(limit) if limit && limit >= 0

  meetups.each_with_index do |m, idx|
    normalized_url = normalize_meetup_url(m[:url])
    warn "Fetching next meetup for #{idx + 1}/#{meetups.size}: #{normalized_url}" if verbose

    json = fetch_next_meetup_via_cloudflare(meetup_url: normalized_url, token: token)
    success = json.is_a?(Hash) && json["success"] == true

    if success
      extracted = json["result"].is_a?(Hash) ? json["result"] : {}

      maybe_append_next_meetup_to_videos(meetup: m, extracted: extracted)
    end

    $stdout.flush
  end

  puts "Done. Be sure to manually check slugs, and run bin/lint to lint the videos.yml files"

  nil
end

if __FILE__ == $PROGRAM_NAME
  limit_arg = ARGV.find { |a| a.start_with?("--limit=") }
  limit = limit_arg ? limit_arg.split("=").last.to_i : nil

  offset_arg = ARGV.find { |a| a.start_with?("--offset=") }
  offset = offset_arg ? offset_arg.split("=").last.to_i : 0

  fetch_next_meetups(limit: limit, offset: offset, verbose: true)
end
