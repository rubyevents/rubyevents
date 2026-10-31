namespace :organizations_file do
  desc "Show organizations.yml stats"
  task stats: :environment do
    organizations = Static::Organization.all

    puts "Organizations: #{organizations.count}"
    puts "Known slugs (incl. aliases): #{organizations.known_slugs.size}"
    puts "Referenced in sponsors/involvements: #{organizations.all_referenced_slugs.size}"
    puts "Missing from organizations.yml: #{organizations.missing_organizations.length}"
    puts "Orphaned in organizations.yml: #{organizations.orphaned_organizations.length}"
    puts "Duplicate slugs: #{organizations.duplicate_slugs.size}"
    puts "Duplicate names: #{organizations.duplicate_names.size}"
    puts "Duplicate candidates: #{organizations.duplicate_candidates.size} (bin/rails organizations_file:duplicates)"
  end

  desc "List organization slugs referenced in sponsors or involvements but missing from organizations.yml"
  task missing: :environment do
    missing = Static::Organization.all.missing_organizations

    if missing.empty?
      puts "All referenced organizations exist in organizations.yml"
    else
      puts "Missing organizations (#{missing.length}):"
      puts
      missing.each { |slug| puts "  - #{slug}" }
    end
  end

  desc "Add missing organizations to organizations.yml, named after their slug"
  task add_missing: :environment do
    organizations = Static::Organization.all
    added = organizations.add_missing_organizations

    if added.empty?
      puts "No missing organizations to add"
    else
      puts "Added #{added.length} organizations:"
      puts
      added.each { |slug| puts "  + #{slug}" }

      organizations.save!
      puts
      puts "Saved organizations.yml (#{organizations.count} total). Fill in their names and websites."
    end
  end

  desc "List orphaned organizations in organizations.yml (not referenced in any sponsors or involvements file)"
  task orphaned: :environment do
    orphaned = Static::Organization.all.orphaned_organizations

    if orphaned.empty?
      puts "No orphaned organizations found"
    else
      puts "Orphaned organizations (#{orphaned.length}):"
      puts
      orphaned.sort.each { |slug| puts "  - #{slug}" }
    end
  end

  desc "Remove orphaned organizations from organizations.yml"
  task remove_orphaned: :environment do
    organizations = Static::Organization.all
    removed = organizations.remove_orphaned_organizations!

    if removed.empty?
      puts "No orphaned organizations to remove"
    else
      puts "Removed #{removed.length} organizations:"
      puts
      removed.sort.each { |slug| puts "  - #{slug}" }

      organizations.save!
      puts
      puts "Saved organizations.yml (#{organizations.count} total)"
    end
  end

  desc "Sync organizations.yml: add missing and remove orphaned organizations"
  task sync: :environment do
    organizations = Static::Organization.all
    added = organizations.add_missing_organizations
    removed = organizations.remove_orphaned_organizations!

    if added.empty? && removed.empty?
      puts "organizations.yml is in sync"
    else
      added.each { |slug| puts "  + #{slug}" }
      removed.sort.each { |slug| puts "  - #{slug}" }

      organizations.save!
      puts
      puts "Saved organizations.yml (#{organizations.count} total)"
    end
  end

  desc "List organizations that may be duplicates (shared website domain or near-identical names); merge them by hand via aliases"
  task duplicates: :environment do
    candidates = Static::Organization.all.duplicate_candidates

    if candidates.empty?
      puts "No duplicate candidates found"
    else
      puts "Duplicate candidates (#{candidates.length}):"
      puts
      candidates.each { |candidate| puts "  #{candidate.slugs.join(", ")} #{candidate.reason}" }
      puts
      puts "To merge, move the slug into the `aliases` of the organization to keep, then run bin/rails organizations_file:extract"
    end
  end

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
