# frozen_string_literal: true

module Static
  # Imports the CFPs, sponsors and involvements of an event or a whole series into the record that owns them.
  # Series entries can carry a `from` and `to`, which become `started_on` and `ended_on`.
  module OwnedImports
    private

    def import_cfps_into!(owner, entries)
      entries.each do |cfp_data|
        cfp = owner.cfps.find_or_initialize_by(link: cfp_data["link"])

        cfp.assign_attributes(
          name: cfp_data["name"],
          open_date: cfp_data["open_date"],
          close_date: cfp_data["close_date"]
        )

        cfp.save! if cfp.changed? || cfp.new_record?
      end
    end

    def import_sponsors_into!(owner, entries)
      require "public_suffix"

      sponsor_ids = []

      entries.each do |sponsors_entry|
        sponsors_entry["tiers"].each do |tier|
          tier["sponsors"].each do |sponsor|
            organization = sponsor_organization(sponsor)

            sponsor_record = owner.sponsors.find_or_initialize_by(
              organization: organization,
              tier: tier["name"].presence,
              started_on: ::Sponsor.period_start(sponsor["from"])
            )
            sponsor_record.assign_attributes(badge: sponsor["badge"], level: tier["level"], ended_on: ::Sponsor.period_end(sponsor["to"]))
            sponsor_record.save! if sponsor_record.changed? || sponsor_record.new_record?

            sponsor_ids << sponsor_record.id
          end
        end
      end

      owner.sponsors.where.not(id: sponsor_ids).destroy_all
    rescue ActiveRecord::RecordInvalid => e
      error_location = ActiveSupport::BacktraceCleaner.new.clean_locations(e.backtrace_locations).first
      puts "::error file=#{error_location&.path},line=#{error_location&.lineno}::#{e.record.class} (#{e.record&.to_param}) - #{e.detailed_message}"
      raise e
    end

    def sponsor_organization(sponsor)
      organization = nil
      domain = nil

      if sponsor["website"].present?
        begin
          uri = URI.parse(sponsor["website"])
          host = uri.host || sponsor["website"]
          parsed = PublicSuffix.parse(host)
          domain = parsed.domain

          organization = ::Organization.find_by(domain: domain) if domain.present?
        rescue PublicSuffix::Error, URI::InvalidURIError
        end
      end

      organization ||= ::Organization.find_by_name_or_alias(sponsor["name"]) || ::Organization.find_by_slug_or_alias(sponsor["slug"]&.downcase)
      organization ||= ::Organization.find_or_initialize_by(name: sponsor["name"])

      # Names like "フィヨルドブートキャンプ" parameterize to "", so fall back to the sponsor's slug
      if organization.new_record? && sponsor["name"].to_s.parameterize.blank?
        organization.slug = sponsor["slug"].to_s.parameterize
      end

      organization.update(
        website: sponsor["website"],
        description: sponsor["description"],
        domain: domain
      )

      organization.add_logo_url(sponsor["logo_url"]) if sponsor["logo_url"].present?
      organization.logo_url = sponsor["logo_url"] if sponsor["logo_url"].present? && organization.logo_url.blank?

      unless organization.persisted?
        organization = ::Organization.find_by_slug_or_alias(organization.slug) || ::Organization.find_by_name_or_alias(organization.name) || organization
      end

      organization.save! if organization.changed? || organization.new_record?

      organization
    end

    def import_involvements_into!(owner, entries)
      involvement_ids = []

      entries.each do |involvement_data|
        role = involvement_data["name"]
        users = Array.wrap(involvement_data["users"]).select { |item| Yerba::Record::References.reference_name(item).present? }
        organisations = Array.wrap(involvement_data["organisations"]).select { |item| Yerba::Record::References.reference_name(item).present? }

        members = users.map { |item| [item, involvement_user(Yerba::Record::References.reference_name(item))] } +
          organisations.map { |item| [item, involvement_organization(Yerba::Record::References.reference_name(item))] }

        members.each_with_index do |(item, involvementable), position|
          period = item.is_a?(Hash) ? item : {}

          involvement = owner.event_involvements.find_or_initialize_by(
            role: role,
            involvementable: involvementable,
            started_on: ::EventInvolvement.period_start(period["from"])
          )
          involvement.assign_attributes(position: position, ended_on: ::EventInvolvement.period_end(period["to"]))
          involvement.save! if involvement.changed? || involvement.new_record?

          involvement_ids << involvement.id
        end
      end

      owner.event_involvements.where.not(id: involvement_ids).destroy_all
    end

    def involvement_user(name)
      user = ::User.find_by_name_or_alias(name)
      return user if user

      puts "Creating user: #{name}" unless Rails.env.test?
      ::User.create!(name: name)
    end

    def involvement_organization(name)
      organization = ::Organization.find_by_name_or_alias(name) || ::Organization.find_by_slug_or_alias(name.parameterize)
      return organization if organization

      puts "Creating organization: #{name}" unless Rails.env.test?
      ::Organization.create!(name: name)
    end
  end
end
