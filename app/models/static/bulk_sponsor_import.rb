# frozen_string_literal: true

module Static
  class BulkSponsorImport
    def self.run!
      new.run!
    end

    def initialize
      require "public_suffix"
      @events_by_slug = ::Event.all.index_by(&:slug)
    end

    def run!
      preload

      Static::Event.all.each do |static_event|
        event = @events_by_slug[static_event.slug]
        next unless event
        next unless event.sponsors_file.exist?

        import_event(static_event, event)
      end
    end

    private

    def preload
      organizations = ::Organization.all.to_a
      @org_by_id = organizations.index_by(&:id)
      @org_by_domain = {}
      @org_by_name = {}
      @org_by_slug = {}

      organizations.each do |org|
        @org_by_domain[org.domain] = org if org.domain.present?
        @org_by_name[org.name] ||= org
        @org_by_slug[org.slug] ||= org if org.slug.present?
      end

      @alias_org_by_name = {}
      @alias_org_by_slug = {}

      ::Alias.where(aliasable_type: "Organization").pluck(:name, :slug, :aliasable_id).each do |name, slug, org_id|
        org = @org_by_id[org_id]
        next unless org

        @alias_org_by_name[name] ||= org
        @alias_org_by_slug[slug] ||= org if slug.present?
      end

      sponsors = ::Sponsor.all.to_a
      @sponsor_by_key = sponsors.index_by { |sponsor| [sponsor.event_id, sponsor.organization_id] }
      @sponsors_by_event = sponsors.group_by(&:event_id)
    end

    def import_event(static_event, event)
      organization_ids = []

      event.sponsors_file.file.each do |sponsors|
        sponsors["tiers"].each do |tier|
          tier["sponsors"].each do |sponsor|
            organization = resolve_and_update_organization(sponsor)
            organization_ids << organization.id

            persist_sponsor(event, organization, tier, sponsor)
          end
        end
      end

      stale = Array(@sponsors_by_event[event.id]).reject { |sponsor| organization_ids.include?(sponsor.organization_id) }

      ::Sponsor.where(id: stale.map(&:id)).delete_all if stale.any?
    rescue ActiveRecord::RecordInvalid => e
      error_location = ActiveSupport::BacktraceCleaner.new.clean_locations(e.backtrace_locations).first
      puts "::error file=#{error_location&.path},line=#{error_location&.lineno}::#{e.record.class} (#{e.record&.to_param}) - #{e.detailed_message}"
      raise e
    end

    def resolve_and_update_organization(sponsor)
      domain = domain_for(sponsor["website"])

      organization = (domain.present? ? @org_by_domain[domain] : nil)
      organization ||= @org_by_name[sponsor["name"]] || @alias_org_by_name[sponsor["name"]]
      organization ||= slug_lookup(sponsor["slug"]&.downcase)
      organization ||= ::Organization.new(name: sponsor["name"])

      organization.assign_attributes(
        website: sponsor["website"],
        description: sponsor["description"],
        domain: domain
      )

      if sponsor["logo_url"].present?
        organization.add_logo_url(sponsor["logo_url"])
        organization.logo_url = sponsor["logo_url"] if organization.logo_url.blank?
      end

      unless organization.persisted?
        organization.valid?
        existing = slug_lookup(organization.slug) || @org_by_name[organization.name] || @alias_org_by_name[organization.name]
        organization = existing if existing && !existing.equal?(organization)
      end

      organization.save! if organization.changed? || organization.new_record?

      register(organization)
      organization
    end

    def persist_sponsor(event, organization, tier, sponsor)
      key = [event.id, organization.id]
      sponsor_record = @sponsor_by_key[key] || event.sponsors.build(organization: organization)
      sponsor_record.assign_attributes(tier: tier["name"], badge: sponsor["badge"], level: tier["level"])
      sponsor_record.save! if sponsor_record.changed? || sponsor_record.new_record?

      @sponsor_by_key[key] = sponsor_record
    end

    def slug_lookup(slug)
      return nil if slug.blank?

      @org_by_slug[slug] || @alias_org_by_slug[slug]
    end

    def domain_for(website)
      return nil if website.blank?

      uri = URI.parse(website)
      host = uri.host || website

      PublicSuffix.parse(host).domain
    rescue PublicSuffix::Error, URI::InvalidURIError
      nil
    end

    def register(organization)
      @org_by_id[organization.id] = organization
      @org_by_domain[organization.domain] = organization if organization.domain.present?
      @org_by_name[organization.name] ||= organization
      @org_by_slug[organization.slug] ||= organization if organization.slug.present?
    end
  end
end
