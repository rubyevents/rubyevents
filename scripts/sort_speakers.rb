# Re-sorts the ./data/speakers.yml file by name
# This avoids the large reformatting diff if we were to just load and resave as YAML

PATH_TO_DATA = "./data/speakers.yml"

def speaker_sort_key(block)
  block
    .split("\n")
    .first
    .sub(/^- name:\s*["']/, "")
    .sub(/["']\s*$/, "")
    .strip
    .downcase
end

raw = File.read(PATH_TO_DATA)
parts = raw.split(/\n(?=- name: )/)

preamble = parts.first
chunks = parts[1..].sort_by { |block| speaker_sort_key(block) }

File.write(PATH_TO_DATA, [preamble, *chunks].join("\n"))

puts "Sorted #{chunks.size} speakers and rewrote to #{PATH_TO_DATA}"
