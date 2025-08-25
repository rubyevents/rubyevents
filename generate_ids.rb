require "securerandom"
require "active_support/all"

# create a csv file with 1000 rows and 1 column. The column should be called "id" and the values should be a code of random 6 characters (numbers and letters). Check so it's not repeating.

ids = []

5100.times do
  id = SecureRandom.hex(6).first(6).upcase
  ids << id
end

# ensure no duplicates and remove duplicates
ids = ids.uniq
ids = ids.first(5000).sort

File.open("ids.csv", "w") do |file|
  file.write(ids.join("\n"))
end
