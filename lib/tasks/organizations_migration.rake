# One-time migration of the organizations in sponsors.yml and involvements.yml into data/organizations.yml.
namespace :organizations_file do
  desc "Crawl www.rubyevents.org into the production snapshot that organizations_file:extract uses (SNAPSHOT=path, BASE_URL=..., DELAY=seconds)"
  task snapshot: :environment do
    path = ENV.fetch("SNAPSHOT", Static::Organization::Snapshot::DEFAULT_PATH.to_s)
    slugs = Static::Organization::Extraction.referenced_slugs

    snapshot = Static::Organization::Snapshot.crawl(
      slugs: slugs,
      base_url: ENV.fetch("BASE_URL", Static::Organization::Snapshot::DEFAULT_BASE_URL),
      delay: ENV.fetch("DELAY", "0.3").to_f
    )
    snapshot.write(path)

    puts "Wrote #{path}: #{snapshot.organizations.size} organizations, #{snapshot.aliases.size} aliases, #{snapshot.unknown.size} slugs unknown to production"
  end

  desc "Extract organizations from sponsors.yml and involvements.yml into organizations.yml (SNAPSHOT=path to the production snapshot)"
  task extract: :environment do
    path = ENV.fetch("SNAPSHOT", Static::Organization::Snapshot::DEFAULT_PATH.to_s)
    snapshot = Static::Organization::Snapshot.load(path)

    puts(snapshot ? "Using production snapshot #{path} (crawled #{snapshot.crawled_at})" : "No production snapshot at #{path}, grouping by the old import rules only")

    Static::Organization::Extraction.new(snapshot: snapshot).run!
  end
end
