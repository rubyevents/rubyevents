# frozen_string_literal: true

module Static
  class Organization
    # One-time migration: moves the organization data out of the sponsors.yml and involvements.yml files into
    # data/organizations.yml, leaving sponsor entries with `slug`, `badge`, `from` and `to`, and involvements with
    # organization slugs instead of names.
    #
    # Grouping follows production (see Snapshot): a slug production lists keeps its slug and name; a slug production
    # folded into another organization becomes an alias of it. Slugs production doesn't know are grouped the way the
    # old import did (same website domain or name), the shortest slug winning. Where several slugs merge, the original
    # entries are kept as a YAML comment under the merged organization's slug. Every decision production didn't make
    # is listed in DECISIONS_PATH for review.
    class Extraction
      SponsorEntry = Struct.new(:record, :tier, :entry, :slug, :name, :website, :logo_url, :description, :event_slug, :date, :file, keyword_init: true)
      InvolvementReference = Struct.new(:record, :name, :file, keyword_init: true)

      Group = Struct.new(:canonical, :slugs, :production, keyword_init: true) do
        def merged?
          slugs.size > 1
        end
      end

      LEGACY_SPONSOR_KEYS = %w[name website logo_url description].freeze
      # Lists organization names before the migration, slugs after it
      LEGACY_INVOLVEMENT_KEY = "organizations"

      DECISIONS_PATH = Rails.root.join("lib/tasks/organizations_file/heuristic_decisions.md")
      DECISION_SECTIONS = {
        by_events: "Slugs production doesn't know, matched to a production organization that lists all their events",
        by_domain: "Slugs production doesn't know, joined to a production organization with the same website domain " \
          "(several candidates: most matching slugs, then the shortest slug, then the alphabetically last)",
        old_rules: "Slugs no production organization matched, grouped by the old import rules (same website domain or " \
          "name), the shortest slug winning, then the alphabetically first",
        values: "Values picked from several in the sponsors.yml entries, where production has none: the most frequent " \
          "(ties: the most recent event, then the alphabetically last; for websites only the latter); the others become " \
          "alternate names, websites or logo URLs, except for descriptions",
        duplicates: "Sponsor entries removed after merging because the tier already lists the organization (the first entry stays)"
      }.freeze

      attr_reader :report

      def initialize(snapshot: nil, log: $stdout)
        @snapshot = snapshot
        @log = log
        @decisions = Hash.new { |hash, section| hash[section] = [] }
      end

      def self.referenced_slugs
        slugs = (Static::Sponsor.all.to_a + Static::SeriesSponsor.all.to_a).flat_map { |record| record.tiers.flat_map { |tier| tier.sponsors.map { |entry| entry["slug"].to_s } } }
        names = (Static::Involvement.all.to_a + Static::SeriesInvolvement.all.to_a).flat_map { |record| Array(record[LEGACY_INVOLVEMENT_KEY]).map { |item| Yerba::Record::References.reference_value(item, "name").to_s } }

        (slugs + names.map { |name| Static::Organization.slug_for(name) }).compact_blank.uniq.sort
      end

      def run!
        collect!
        resolve_groups!
        build_organizations!
        write_organizations!
        rewrite_sponsors!
        rewrite_involvements!

        Static::Organization.unload!
        print_report
        write_decisions!

        report
      end

      private

      # --- collecting -------------------------------------------------------------------------------------------

      def collect!
        @entries = []
        @involvement_references = []

        (Static::Sponsor.all.to_a + Static::SeriesSponsor.all.to_a).each do |record|
          event = record.is_a?(Static::Sponsor) ? record.event : nil
          date = event&.start_date
          date = nil unless date.is_a?(Date)

          record.tiers.each do |tier|
            tier.sponsors.each do |entry|
              @entries << SponsorEntry.new(
                record: record, tier: tier, entry: entry,
                slug: entry["slug"].to_s, name: entry["name"].to_s.strip.presence, website: entry["website"].to_s.strip.presence,
                logo_url: entry["logo_url"].to_s.strip.presence, description: entry["description"].to_s.strip.presence,
                event_slug: event&.slug, date: date, file: record.project_file_path
              )
            end
          end
        end

        (Static::Involvement.all.to_a + Static::SeriesInvolvement.all.to_a).each do |record|
          Array(record[LEGACY_INVOLVEMENT_KEY]).each do |item|
            name = Yerba::Record::References.reference_value(item, "name").to_s.strip
            next if name.blank?

            @involvement_references << InvolvementReference.new(record: record, name: name, file: record.project_file_path)
          end
        end

        @existing = Static::Organization.all.to_a
        @existing_canonical = {}
        @existing.each do |organization|
          @existing_canonical[organization.slug] = organization.slug
          organization.alias_slugs.each { |slug| @existing_canonical[slug] = organization.slug }
        end
      end

      def entries_by_slug
        @entries_by_slug ||= @entries.group_by(&:slug)
      end

      def events_of(slug)
        entries_by_slug.fetch(slug, []).filter_map(&:event_slug).uniq
      end

      def names_of(slug)
        names = entries_by_slug.fetch(slug, []).filter_map(&:name)
        names += @involvement_references.select { |reference| involvement_slug(reference) == slug }.map(&:name)
        names
      end

      def domains_of(slug)
        entries_by_slug.fetch(slug, []).filter_map { |entry| Static::Organization.registrable_domain(entry.website) if entry.website }.uniq
      end

      # The slug an involvement's organization name gets: production's slug for that name, or the name parameterized
      # the way the organizations table does it
      def involvement_slug(reference)
        involvement_slug_for_name(reference.name, file: reference.file)
      end

      def involvement_slug_for_name(name, file: nil)
        @involvement_slugs ||= {}
        @involvement_slugs[name] ||= begin
          existing = @existing.find { |organization| organization.all_names.include?(name) }

          existing&.slug ||
            @snapshot&.slug_by_name(name) ||
            Static::Organization.slug_for(name).presence ||
            raise(InvalidOrganizationError, "Cannot derive a slug for organization '#{name}'#{" in #{file}" if file}")
        end
      end

      def yaml_slugs
        @yaml_slugs ||= (entries_by_slug.keys + @involvement_references.map { |reference| involvement_slug(reference) }).uniq.sort
      end

      # --- grouping ---------------------------------------------------------------------------------------------

      def resolve_groups!
        @canonical = {}
        @groups = {}

        pending = yaml_slugs.reject { |slug| @existing_canonical.key?(slug) }
        yaml_slugs.each { |slug| @canonical[slug] = @existing_canonical[slug] if @existing_canonical.key?(slug) }

        production = {}
        if @snapshot
          pending.each do |slug|
            target = production_slug_for(slug)
            production[slug] = target if target
          end
        end

        unresolved = pending - production.keys

        # A slug production doesn't know joins the production organization its website domain already belongs to,
        # which is what the next import on production would do
        unresolved.dup.each do |slug|
          candidates = domains_of(slug).flat_map { |domain| production.select { |other, _| domains_of(other).include?(domain) }.values }
          next if candidates.empty?

          tally = candidates.tally
          preferred = tally.max_by { |candidate, count| [count, -candidate.length, candidate] }.first
          production[slug] = preferred
          unresolved.delete(slug)
          others = tally.except(preferred).map { |candidate, count| "`#{candidate}` (#{count})" }
          decide(:by_domain, "`#{slug}` → `#{preferred}` (#{tally[preferred]}), #{domains_of(slug).join(", ")}#{"; over #{others.join(", ")}" if others.any?}")
        end

        production.group_by(&:last).each do |target, pairs|
          slugs = (pairs.map(&:first) + [target]).uniq
          @groups[target] = Group.new(canonical: target, slugs: slugs.sort_by { |slug| [(slug == target) ? 0 : 1, slug] }, production: @snapshot.organization(target))
          slugs.each { |slug| @canonical[slug] = target }
        end

        closure_groups(unresolved).each do |slugs|
          canonical = slugs.min_by { |slug| [slug.length, slug] }
          decide(:old_rules, "`#{canonical}`#{" absorbs #{(slugs - [canonical]).map { |slug| "`#{slug}`" }.join(", ")}" if slugs.size > 1}")
          @groups[canonical] = Group.new(canonical: canonical, slugs: slugs.sort_by { |slug| [(slug == canonical) ? 0 : 1, slug] }, production: nil)
          slugs.each { |slug| @canonical[slug] = canonical }
        end
      end

      def production_slug_for(slug)
        target = @snapshot.canonical_slug(slug)
        return target if target

        covering = @snapshot.slugs_covering_events(events_of(slug))
        return nil if covering.empty?
        return matched_by_events(slug, covering.first, "the only one") if covering.size == 1

        domains = domains_of(slug)
        by_domain = covering.select do |candidate|
          website = @snapshot.organization(candidate)["website"]
          website && domains.include?(Static::Organization.registrable_domain(website))
        end
        return matched_by_events(slug, by_domain.first, "the only one of #{covering.size} with its website domain #{domains.join(", ")}") if by_domain.size == 1

        names = names_of(slug).map(&:downcase)
        by_name = covering.select { |candidate| names.include?(@snapshot.organization(candidate)["name"].to_s.downcase) }
        return matched_by_events(slug, by_name.first, "the only one of #{covering.size} with its name") if by_name.size == 1

        nil
      end

      def matched_by_events(slug, target, reason)
        decide(:by_events, "`#{slug}` → `#{target}`, #{reason}; events: #{events_of(slug).join(", ")}")
        target
      end

      # Union-find over the rules the old import matched with: same slug, same website domain, same name
      def closure_groups(slugs)
        parent = slugs.to_h { |slug| [slug, slug] }
        root = ->(slug) { (parent[slug] == slug) ? slug : (parent[slug] = root.call(parent[slug])) }
        union = ->(a, b) { parent[root.call(a)] = root.call(b) }

        by_domain = Hash.new { |hash, key| hash[key] = [] }
        by_name = Hash.new { |hash, key| hash[key] = [] }

        slugs.each do |slug|
          domains_of(slug).each { |domain| by_domain[domain] << slug }
          names_of(slug).map(&:downcase).uniq.each { |name| by_name[name] << slug }
        end

        (by_domain.values + by_name.values).each { |members| members.each_cons(2) { |a, b| union.call(a, b) } }

        slugs.group_by { |slug| root.call(slug) }.values.map(&:sort)
      end

      # --- building ---------------------------------------------------------------------------------------------

      def build_organizations!
        @new_organizations = @groups.values.sort_by(&:canonical).map { |group| organization_for(group) }
        @comments = @groups.values.select(&:merged?).to_h { |group| [group.canonical, merged_from_comment(group)] }
      end

      def organization_for(group)
        entries = group.slugs.flat_map { |slug| entries_by_slug.fetch(slug, []) }
        production = group.production || {}
        canonical_entries = entries_by_slug.fetch(group.canonical, [])

        name = production["name"].presence ||
          top_decided(group.canonical, "name", values_of(canonical_entries, :name)) ||
          top_decided(group.canonical, "name", values_of(entries, :name)) ||
          involvement_name_for(group.canonical) || group.canonical.titleize

        aliases = (group.slugs - [group.canonical]).map do |slug|
          {"name" => top_decided(group.canonical, "alias #{slug} name", values_of(entries_by_slug.fetch(slug, []), :name)) || involvement_name_for(slug) || slug.titleize, "slug" => slug}
        end

        all_names = (entries.filter_map(&:name) + group.slugs.flat_map { |slug| @involvement_references.select { |reference| involvement_slug(reference) == slug }.map(&:name) }).uniq
        alternate_names = (all_names - [name] - aliases.map { |entry| entry["name"] }).sort

        website_groups = values_of(entries, :website).group_by { |website, _| normalize_url(website) }.values
        # Each URL by its most frequent spelling; the most frequent URL wins, ties go to the alphabetically last
        website_counts = website_groups.to_h { |values| [top(values), values.size] }
        website = production["website"].presence ||
          decided(group.canonical, "website", website_counts.max_by { |raw, count| [count, raw] }&.first, website_counts)
        websites = other_variants(website_groups) { |raw| normalize_url(raw) == normalize_url(website) }

        logo_groups = values_of(entries, :logo_url).group_by(&:first).values
        logo_url = production["logo_url"].presence || top_decided(group.canonical, "logo_url", logo_groups.flatten(1))
        logo_urls = other_variants(logo_groups) { |raw| raw == logo_url }

        description = production["description"].presence || top_decided(group.canonical, "description", values_of(entries, :description))
        logo_background = production["logo_background"].presence
        logo_background = nil if logo_background == "white"

        {
          "slug" => group.canonical,
          "aliases" => aliases.presence,
          "name" => name,
          "alternate_names" => alternate_names.presence,
          "website" => website,
          "websites" => websites.presence,
          "logo_url" => logo_url,
          "logo_urls" => logo_urls.presence,
          "logo_background" => logo_background,
          "main_location" => production["main_location"].presence,
          "description" => description
        }.compact
      end

      def involvement_name_for(slug)
        @involvement_references.find { |reference| involvement_slug(reference) == slug }&.name
      end

      # [value, date] pairs of the entries that have `field`
      def values_of(entries, field)
        entries.filter_map { |entry| [entry.public_send(field), entry.date] if entry.public_send(field).present? }
      end

      # Most frequent value; ties go to the most recent event, then to the alphabetically last
      def top(pairs)
        pairs.group_by(&:first).max_by { |value, values| [values.size, latest(values)&.jd || 0, value] }&.first
      end

      def top_decided(slug, field, pairs)
        decided(slug, field, top(pairs), pairs.map(&:first).tally)
      end

      # `picked` out of `counts` ({value => count}), listed as a decision when there was more than one value
      def decided(slug, field, picked, counts)
        if picked && counts.size > 1
          others = counts.except(picked).map { |value, count| "#{value.truncate(100).to_json} (#{count})" }
          decide(:values, "`#{slug}` #{field}: #{picked.truncate(100).to_json} (#{counts[picked]}) over #{others.join(", ")}")
        end

        picked
      end

      # The other spellings or URLs seen in a group, each by its most frequent raw form, most frequent first
      # (then most recent, then alphabetical); `groups` are [value, date] pairs grouped by what counts as one variant
      def other_variants(groups)
        groups.map { |values| [top(values), values.size, latest(values)] }
          .reject { |raw, _, _| yield(raw) }
          .sort_by { |raw, count, date| [-count, date ? -date.jd : 0, raw] }
          .map(&:first)
      end

      def latest(pairs)
        pairs.filter_map(&:last).max
      end

      def normalize_url(url)
        url.to_s.strip.downcase.sub(%r{\Ahttps?://}, "").sub(/\Awww\./, "").sub(/[?#].*\z/, "").sub(%r{/+\z}, "")
      end

      # The original entries of a merged group, as commented YAML right under the merged organization's slug.
      # That spot survives the Yerbafile: the slug stays the first key, items are sorted as a whole, and blank
      # lines go between items.
      def merged_from_comment(group)
        lines = ["  # Merged from:"]

        group.slugs.each do |slug|
          entries = entries_by_slug.fetch(slug, [])
          sources = (entries.map(&:file) + @involvement_references.select { |reference| involvement_slug(reference) == slug }.map(&:file)).uniq.sort
          next if sources.empty?

          original = {
            "slug" => slug,
            "name" => top(values_of(entries, :name)) || involvement_name_for(slug),
            "website" => top(values_of(entries, :website)),
            "logo_url" => top(values_of(entries, :logo_url))
          }.compact

          original.each_with_index do |(key, value), index|
            lines << "  # #{index.zero? ? "- " : "  "}#{key}: #{value.to_json}"
          end
          lines << "  #   sources:"
          sources.each { |source| lines << "  #     - #{source.to_json}" }
        end

        lines
      end

      # --- writing ----------------------------------------------------------------------------------------------

      def write_organizations!
        return if @new_organizations.empty?

        path = Static::Organization.file_path
        File.write(path, "---\n[]\n") unless File.exist?(path)

        Static::Organization.unload!
        collection = Static::Organization.all
        @new_organizations.each { |attributes| collection.build(attributes) }
        collection.save!

        inject_comments!(path)
      end

      def inject_comments!(path)
        return if @comments.empty?

        lines = File.readlines(path, chomp: true)
        output = []

        lines.each do |line|
          output << line

          slug = line[/\A- slug: "?([^"]+)"?\z/, 1]
          output.concat(@comments[slug]) if slug && @comments.key?(slug)
        end

        File.write(path, output.join("\n") + "\n")
        Yerba.parse_file(path.to_s).save!(apply: true) # rubocop:disable RubyEvents/PreferStaticModels
      end

      def rewrite_sponsors!
        @rewritten_sponsor_files = 0
        @deduplicated = []

        @entries.group_by(&:record).each do |record, entries|
          changed = false
          duplicates = []

          entries.group_by(&:tier).each do |tier, tier_entries|
            seen = {}

            tier_entries.each do |sponsor|
              target = @canonical.fetch(sponsor.slug)

              LEGACY_SPONSOR_KEYS.each do |key|
                next unless sponsor.entry.key?(key)

                sponsor.entry.delete(key)
                changed = true
              end

              # Two slugs of one organization in the same tier: keep the first entry, destroyed below
              if seen.key?(target)
                kept = seen[target]
                kept.entry["badge"] = sponsor.entry["badge"] if sponsor.entry["badge"].present? && kept.entry["badge"].blank?
                @deduplicated << [sponsor.file, sponsor.slug, target]
                decide(:duplicates, "#{sponsor.file}, tier #{tier["name"].to_json}: " +
                  ((sponsor.slug == kept.slug) ? "`#{target}` listed twice" : "`#{sponsor.slug}` after `#{kept.slug}`, both now `#{target}`"))
                duplicates << sponsor.entry
                next
              end

              seen[target] = sponsor

              if sponsor.entry["slug"] != target
                sponsor.entry["slug"] = target
                changed = true
              end
            end
          end

          next unless changed

          # destroy saves the document each time, so strip every entry first (above) and remove from the end
          duplicates.sort_by(&:index).reverse_each(&:destroy)
          record.save!
          @rewritten_sponsor_files += 1
        end
      end

      def rewrite_involvements!
        @rewritten_involvement_files = 0

        records = (Static::Involvement.all.to_a + Static::SeriesInvolvement.all.to_a).select { |record| record.key?(LEGACY_INVOLVEMENT_KEY) }

        # One save per file: a file holds several roles, and saving validates the whole file
        records.group_by(&:file_path).each_value do |file_records|
          file_records.each do |record|
            # Item by item, so comments next to an organization's name stay next to its slug
            Array(record[LEGACY_INVOLVEMENT_KEY]).each_with_index do |item, index|
              name = Yerba::Record::References.reference_value(item, "name").to_s.strip
              slug = @canonical.fetch(involvement_slug_for_name(name))
              selector = "#{record.selector}.#{LEGACY_INVOLVEMENT_KEY}[#{index}]"

              if item.is_a?(Hash)
                record.document.rename("#{selector}.name", "#{selector}.slug")
                record.document.set("#{selector}.slug", slug)
              else
                record.document.set(selector, slug)
              end
            end
          end

          file_records.first.save!
          @rewritten_involvement_files += 1
        end
      end

      # --- reporting --------------------------------------------------------------------------------------------

      def print_report
        merged = @groups.values.select(&:merged?)
        fallback = @groups.values.reject(&:production)

        @report = {
          organizations_added: @new_organizations.size,
          merged_groups: merged.map { |group| [group.canonical, group.slugs - [group.canonical]] }.to_h,
          fallback_groups: fallback.map(&:canonical).sort,
          involvement_slugs: @involvement_references.map { |reference| [reference.name, @canonical.fetch(involvement_slug(reference))] }.uniq.sort.to_h,
          deduplicated_sponsors: @deduplicated,
          rewritten_sponsor_files: @rewritten_sponsor_files,
          rewritten_involvement_files: @rewritten_involvement_files
        }

        @log.puts "Added #{report[:organizations_added]} organizations to #{Static::Organization.file_path}"
        @log.puts "Rewrote #{report[:rewritten_sponsor_files]} sponsors.yml and #{report[:rewritten_involvement_files]} involvements.yml files"
        @log.puts "Merged #{merged.size} groups (#{merged.sum { |group| group.slugs.size - 1 }} slugs became aliases)"
        @log.puts "#{fallback.size} groups without a production match, grouped by the old import rules: #{fallback.map(&:canonical).sort.join(", ")}" if fallback.any?
        @log.puts "Removed #{@deduplicated.size} sponsor entries that duplicated another one in the same tier after merging" if @deduplicated.any?
        @log.puts "Nothing to do" if report[:organizations_added].zero? && report[:rewritten_sponsor_files].zero? && report[:rewritten_involvement_files].zero?
      end

      def decide(section, line)
        @decisions[section] << line
      end

      def write_decisions!
        lines = [
          "# Decisions of organizations_file:extract that production didn't make",
          "",
          "Everything else follows the production snapshot#{" crawled #{@snapshot.crawled_at}" if @snapshot}. " \
          "Numbers in parentheses count sponsors.yml entries or matching slugs."
        ]

        DECISION_SECTIONS.each do |section, title|
          lines.push("", "## #{title}", "", *@decisions[section].map { |line| "- #{line}" }) if @decisions[section].any?
        end

        FileUtils.mkdir_p(DECISIONS_PATH.dirname)
        File.write(DECISIONS_PATH, lines.join("\n") + "\n")
        @log.puts "Listed #{@decisions.values.sum(&:size)} decisions production didn't make in #{DECISIONS_PATH.relative_path_from(Rails.root)}"
      end
    end
  end
end
