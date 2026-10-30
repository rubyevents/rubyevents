# frozen_string_literal: true

# A throwaway organizations.yml for the organization MCP tool tests
module OrganizationToolFile
  extend ActiveSupport::Concern

  included do
    setup do
      @tmp_file = Tempfile.new(["organizations", ".yml"])
      @tmp_file.write(<<~YAML)
        ---
        - slug: "appsignal"
          aliases:
            - name: "App Signal"
              slug: "app-signal"
          name: "AppSignal"
          kind: "company"
          website: "https://www.appsignal.com"

        - slug: "typesense"
          name: "Typesense"
          alternate_names:
            - "TypeSense"
          website: "https://typesense.org"
      YAML
      @tmp_file.flush
    end

    teardown do
      @tmp_file.close
      @tmp_file.unlink
    end
  end
end
