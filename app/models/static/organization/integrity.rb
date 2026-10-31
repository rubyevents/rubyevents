# frozen_string_literal: true

module Static
  class Organization
    # Checks across data/organizations.yml and the files that reference it, like Static::Speaker::Integrity for speakers.
    module Integrity
      DuplicateCandidate = Struct.new(:slugs, :reason, keyword_init: true)

      GENERIC_HOSTS = %w[
        bit.ly meetup.com facebook.com linkedin.com twitter.com x.com github.com instagram.com
        youtube.com google.com notion.site notion.so lu.ma eventbrite.com
      ].freeze

      def slugs
        pluck(:slug)
      end

      def alias_slugs
        all.flat_map(&:alias_slugs)
      end

      def alias_names
        all.flat_map(&:alias_names)
      end

      def known_slugs
        all.cached(:known_slugs) { Set.new(slugs + alias_slugs) }
      end

      def known_slug?(slug)
        known_slugs.include?(slug.to_s)
      end

      def all_organization_references
        all.cached(:all_organization_references) { inbound_references }
      end

      def all_referenced_slugs
        all.cached(:all_referenced_slugs) { Set.new(all_organization_references.map(&:value)) }
      end

      def missing_organization_references
        all_organization_references.reject { |reference| known_slug?(reference.value) }
      end

      def missing_organizations
        missing_organization_references.map(&:value).uniq.sort
      end

      def orphaned_organizations
        orphaned.map(&:slug)
      end

      def remove_orphaned_organizations!
        organizations = orphaned
        return [] if organizations.empty?

        organizations.sort_by(&:index).reverse_each(&:destroy)
        all.reset!

        organizations.map(&:slug)
      end

      def add_missing_organizations(references = missing_organization_references)
        slugs = references.map(&:value).uniq.sort
        slugs.each { |slug| add(slug: slug, name: slug.titleize) }

        slugs
      end

      def duplicate_slugs
        duplicates(:slug)
      end

      def duplicate_names
        duplicates(:name)
      end

      def duplicates(field)
        pluck(field).select(&:present?).tally.select { |_, count| count > 1 }
      end

      # Organizations that may be the same: they share a website's registrable domain, or their names
      # are nearly identical. A report for humans, who merge by moving a slug into `aliases`.
      def duplicate_candidates(threshold: 0.85)
        all.cached([:duplicate_candidates, threshold]) do
          by_domain = Hash.new { |hash, key| hash[key] = [] }

          all.each do |organization|
            organization.all_websites.filter_map { |website| registrable_domain(website) }.uniq.each do |domain|
              next if GENERIC_HOSTS.include?(domain)

              by_domain[domain] << organization.slug
            end
          end

          domain_candidates = by_domain.select { |_, slugs| slugs.uniq.size > 1 }.map do |domain, slugs|
            DuplicateCandidate.new(slugs: slugs.uniq.sort, reason: "share the domain #{domain}")
          end

          seen = domain_candidates.map(&:slugs).to_set
          name_candidates = similar_name_pairs(threshold).filter_map do |pair, score|
            next if seen.include?(pair)

            DuplicateCandidate.new(slugs: pair, reason: "have similar names (#{(score * 100).round}%)")
          end

          (domain_candidates + name_candidates).sort_by { |candidate| candidate.slugs.first }
        end
      end

      def registrable_domain(website)
        require "public_suffix"

        host = URI.parse(website.to_s.strip).host || website.to_s.strip
        PublicSuffix.parse(host).domain
      rescue PublicSuffix::Error, URI::InvalidURIError
        nil
      end

      private

      def orphaned
        referenced = all_referenced_slugs

        all.reject do |organization|
          referenced.include?(organization.slug) || organization.alias_slugs.any? { |slug| referenced.include?(slug) }
        end
      end

      def similar_name_pairs(threshold)
        entries = all.map { |organization| [organization.slug, organization.name.to_s] }
        compact = ->(name) { name.downcase.gsub(/[^a-z0-9]/, "") }

        entries.combination(2).filter_map do |(slug_a, name_a), (slug_b, name_b)|
          a = compact.call(name_a)
          b = compact.call(name_b)
          next if a.empty? || b.empty?
          next if (a.length - b.length).abs > 3

          max = [a.length, b.length].max
          score = 1.0 - (DidYouMean::Levenshtein.distance(a, b).to_f / max)
          next if score < threshold

          [[slug_a, slug_b].sort, score]
        end
      end
    end
  end
end
