# frozen_string_literal: true

module Static
  class Sponsor
    # One sponsor in a tier: the `slug` of an organization in data/organizations.yml, plus what is specific
    # to this sponsorship (`badge`, and `from`/`to` in a series' sponsors.yml).
    class Entry < Yerba::Record::Base
      has_one :event, through: :parent
      has_one :series, through: :parent

      references :organizations, field: "slug", class_name: "Static::Organization", key: "slug"

      def organization
        organizations.first
      end
    end
  end
end
