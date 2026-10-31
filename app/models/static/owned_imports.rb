# frozen_string_literal: true

module Static
  # Imports the CFPs, sponsors and involvements of an event or a whole series into the record that owns them.
  # Series entries can carry a `from` and `to`, which become `started_on` and `ended_on`.
  # Sponsors and involved organizations reference data/organizations.yml by slug, imported by Static::Organization.
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
      sponsor_ids = []

      entries.each do |sponsors_entry|
        sponsors_entry["tiers"].each do |tier|
          tier["sponsors"].each do |sponsor|
            organization = organization_for(sponsor["slug"], entries.relative_path)

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

    def import_involvements_into!(owner, entries)
      involvement_ids = []

      entries.each do |involvement_data|
        role = involvement_data["name"]
        users = Array.wrap(involvement_data["users"]).select { |item| Yerba::Record::References.reference_value(item, "name").present? }
        organizations = Array.wrap(involvement_data["organizations"]).select { |item| Yerba::Record::References.reference_value(item, "slug").present? }

        members = users.map { |item| [item, involvement_user(Yerba::Record::References.reference_value(item, "name"))] } +
          organizations.map { |item| [item, organization_for(Yerba::Record::References.reference_value(item, "slug"), entries.relative_path)] }

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

    # Organizations come from data/organizations.yml, imported before events.
    def organization_for(slug, source)
      organization = ::Organization.find_by_slug_or_alias(slug.to_s)
      return organization if organization

      static_organization = Static::Organization.find_by(slug: slug.to_s)
      return static_organization.import!(index: false) || ::Organization.find_by_slug_or_alias(static_organization.slug) if static_organization

      raise Static::Organization::MissingOrganizationError, "Organization '#{slug}' referenced in #{source} is not in data/organizations.yml"
    end
  end
end
