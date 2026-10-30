# TODO: remove this client

module RubyConferences
  class Client < ApplicationClient
    BASE_URI = "https://raw.githubusercontent.com/ruby-conferences/ruby-conferences.github.io/refs/heads/main"

    def conferences
      Yerba.parse(get("/_data/conferences.yml").body).to_a
    end

    def conferences_cached
      Rails.cache.fetch("ruby-conferences/_data/conferences.yml", expires_in: 1.day) do
        conferences
      end
    end

    private

    def content_type
      "text/yaml"
    end
  end
end
