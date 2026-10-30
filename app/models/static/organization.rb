# frozen_string_literal: true

module Static
  # The organizations in data/organizations.yml: sponsors and the organizations in involvements, referenced by slug.
  class Organization < Yerba::Record::Base
    self.path = "data/organizations.yml"

    schema OrganizationSchema

    add_index :slug, include: "aliases[].slug"
    add_index :name, include: "aliases[].name"

    self.order_by = "slug"

    extend Integrity

    # Fields the import writes whenever the YAML has a value; kind, main_location, logo_background and logo_url
    # only fill a blank column, so admin edits in the database survive
    SYNCED_FIELDS = %w[name website description].freeze
    SEARCH_INDEX_ON_IMPORT_DEFAULT = ENV.fetch("SEARCH_INDEX_ON_IMPORT", "true") == "true"

    class InvalidOrganizationError < StandardError; end
    class DuplicateOrganizationError < StandardError; end
    class MissingOrganizationError < StandardError; end

    def self.slug_for(name)
      I18n.transliterate(name.to_s.strip.downcase).parameterize
    end

    def self.add(slug:, name:, **attributes)
      slug = slug.to_s.strip
      name = name.to_s.strip

      raise InvalidOrganizationError, "Organization slug cannot be blank" if slug.blank?
      raise InvalidOrganizationError, "Organization name cannot be blank" if name.blank?
      raise DuplicateOrganizationError, "Organization '#{slug}' already exists" if known_slug?(slug)
      raise DuplicateOrganizationError, "An organization named '#{name}' already exists" if all.find_by(name: name)

      all.build({"slug" => slug, "name" => name}.merge(clean_attributes(attributes)))
    end

    def self.save!
      all.save!
    end

    def self.clean_attributes(attributes)
      attributes
        .transform_keys(&:to_s)
        .reject { |_, value| value.blank? }
        .transform_values { |value| value.is_a?(String) ? value.strip : value }
    end

    def assign(**attributes)
      self.class.clean_attributes(attributes).each { |key, value| self[key] = value }

      self
    end

    # A former slug and the name it was known under; a no-op when it is already an alias
    def add_alias(name:, slug:)
      slug = slug.to_s
      return self if alias_slugs.include?(slug)

      self["aliases"] = Array(self["aliases"]) + [{"name" => name.to_s, "slug" => slug}]

      self
    end

    # Moves the organization to another slug and keeps the current one as alias, so URLs and references
    # using it still resolve. Renaming back to a former slug takes it out of the aliases again.
    def rename_slug(new_slug)
      new_slug = new_slug.to_s
      return self if new_slug == slug

      add_alias(name: name, slug: slug)
      self["aliases"] = Array(self["aliases"]).reject { |entry| entry["slug"] == new_slug }
      delete("aliases") if self["aliases"].empty?
      self["slug"] = new_slug

      self
    end

    # Renames the organization and keeps the current spelling as alternate name
    def rename(new_name)
      new_name = new_name.to_s
      return self if new_name == name

      former = name
      self["name"] = new_name
      self["alternate_names"] = Array(self["alternate_names"]) - [new_name]
      delete("alternate_names") if self["alternate_names"].empty?

      add_alternate_name(former)
    end

    def add_alternate_name(name)
      return self if name.blank? || name == self["name"] || all_names.include?(name)

      self["alternate_names"] = Array(self["alternate_names"]) + [name.to_s]

      self
    end

    def alias_slugs
      Array(self["aliases"]).filter_map { |entry| entry["slug"] if entry.is_a?(Hash) }
    end

    def alias_names
      Array(self["aliases"]).filter_map { |entry| entry["name"] if entry.is_a?(Hash) }
    end

    def all_names
      [self["name"], *alias_names, *Array(self["alternate_names"])].compact_blank.uniq
    end

    def all_websites
      [self["website"], *Array(self["websites"])].compact_blank.uniq
    end

    def all_logo_urls
      [self["logo_url"], *Array(self["logo_urls"])].compact_blank.uniq
    end

    def self.import_all!(index: SEARCH_INDEX_ON_IMPORT_DEFAULT)
      imported = []
      organizations = all.to_a

      puts "Importing #{organizations.count} organizations..." unless Rails.env.test?

      ::Organization.transaction do
        organizations.each do |organization|
          record = organization.import!(index: false)
          imported << record if record
        end
      end

      imported.each { |record| Search::Backend.index(record) } if imported.any? && index

      imported
    end

    # Writes this entry into the organizations table. kind, main_location, logo_background and logo_url only fill
    # a blank column, so what admins picked in Avo or the logo picker survives a seed; logo_urls are never removed.
    def import!(index: SEARCH_INDEX_ON_IMPORT_DEFAULT)
      organization = ::Organization.find_by(slug: slug) || organization_by_alias_slug || ::Organization.new(slug: slug)
      previous_slug = organization.slug

      organization.slug = slug if organization.slug != slug
      merge_rows_under_alias_slugs!(organization) if organization.persisted?

      SYNCED_FIELDS.each do |field|
        organization[field] = self[field] if self[field].present?
      end

      organization.kind = kind if kind.present? && organization.unknown?
      organization.main_location = main_location if main_location.present? && organization.main_location.blank?
      organization.logo_background = logo_background if logo_background.present? && organization.logo_background.in?([nil, "", "white"])
      organization.logo_url = logo_url if logo_url.present? && organization.logo_url.blank?
      organization.domain = self.class.registrable_domain(organization.website) if organization.website.present?

      all_logo_urls.each { |url| organization.add_logo_url(url) }

      changed = organization.changed? || organization.new_record?
      organization.save! if changed

      import_aliases!(organization, previous_slug: previous_slug)
      warn_about_dropped_logo(organization)

      Search::Backend.index(organization) if index && changed

      changed ? organization : nil
    rescue ActiveRecord::RecordInvalid => e
      puts "Couldn't save organization #{slug}: #{e.message}"
      nil
    end

    private

    def organization_by_alias_slug
      alias_slugs.each do |alias_slug|
        organization = ::Organization.find_by(slug: alias_slug)
        return organization if organization
      end

      nil
    end

    def merge_rows_under_alias_slugs!(organization)
      alias_slugs.each do |alias_slug|
        duplicate = ::Organization.where.not(id: organization.id).find_by(slug: alias_slug)
        next unless duplicate

        puts "Merging organization #{duplicate.slug} into #{slug}" unless Rails.env.test?

        duplicate.sponsors.find_each do |sponsor|
          if organization.sponsors.exists?(event_id: sponsor.event_id, event_series_id: sponsor.event_series_id, tier: sponsor.tier, started_on: sponsor.started_on)
            sponsor.destroy!
          else
            sponsor.update!(organization: organization)
          end
        end

        duplicate.event_involvements.find_each do |involvement|
          if organization.event_involvements.exists?(event_id: involvement.event_id, event_series_id: involvement.event_series_id, role: involvement.role, started_on: involvement.started_on)
            involvement.destroy!
          else
            involvement.update!(involvementable: organization)
          end
        end

        duplicate.logo_urls.each { |url| organization.add_logo_url(url) }
        organization.logo_url = duplicate.logo_url if organization.logo_url.blank? && duplicate.logo_url.present?
        duplicate.aliases.find_each { |record| record.update!(aliasable: organization) }
        duplicate.destroy!
      end
    end

    def import_aliases!(organization, previous_slug:)
      wanted = Array(self["aliases"]).filter_map { |entry| [entry["name"], entry["slug"]] if entry.is_a?(Hash) && entry["slug"].present? }
      wanted << [previous_slug, previous_slug] if previous_slug.present? && previous_slug != slug && wanted.none? { |_, alias_slug| alias_slug == previous_slug }

      wanted.each do |alias_name, alias_slug|
        alias_name = alias_name.presence || alias_slug

        conflicting_alias = ::Alias.where(slug: alias_slug).where.not(aliasable_type: "Organization", aliasable_id: organization.id).first
        conflicting_organization = ::Organization.where(slug: alias_slug).where.not(id: organization.id).first

        if conflicting_alias
          puts "Alias conflict: #{slug} alias '#{alias_name}' (#{alias_slug}) conflicts with alias on #{conflicting_alias.aliasable_type} #{conflicting_alias.aliasable_id}"
          next
        end

        if conflicting_organization
          puts "Alias conflict: #{slug} alias '#{alias_name}' (#{alias_slug}) conflicts with organization #{conflicting_organization.slug}"
          next
        end

        existing = ::Alias.find_by(aliasable: organization, slug: alias_slug)
        next if existing

        if ::Alias.exists?(aliasable_type: "Organization", name: alias_name)
          puts "Alias conflict: #{slug} alias name '#{alias_name}' is already taken by another organization"
          next
        end

        ::Alias.create!(aliasable: organization, name: alias_name, slug: alias_slug)
      end
    end

    def warn_about_dropped_logo(organization)
      return if Rails.env.test?
      return if organization.logo_url.blank? || all_logo_urls.include?(organization.logo_url)

      puts "::warning::Organization #{slug} shows logo #{organization.logo_url}, which is not in its logo_urls in data/organizations.yml"
    end
  end
end
