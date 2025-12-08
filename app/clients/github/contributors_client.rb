module GitHub
  class ContributorsClient < Client
    OWNER = "rubyevents"
    REPO = "rubyevents"

    def fetch_all
      contributors = fetch_contributors
      enrich_with_user_data(contributors)
    end

    private

    def fetch_contributors
      contributors = []
      page = 1
      per_page = 100

      loop do
        response = get("/repos/#{OWNER}/#{REPO}/contributors", query: {page: page, per_page: per_page})
        batch = response.parsed_body

        break if batch.empty?

        contributors.concat(batch.reject { |c| c.login.include?("[bot]") })
        page += 1
      end

      contributors
    end

    def enrich_with_user_data(contributors)
      query_fields = contributors.map.with_index do |contributor, index|
        %{user#{index}: user(login: "#{contributor.login}") { login name avatarUrl url }}
      end.join("\n")

      graphql_query = "{ #{query_fields} }"

      response = post("/graphql", body: {query: graphql_query})
      users = response.parsed_body.data.to_h.values.compact

      users_by_login = users.index_by { |u| u.login }

      contributors.map do |contributor|
        user = users_by_login[contributor.login]
        {
          login: contributor.login,
          name: user&.name,
          avatar_url: user&.avatarUrl || contributor.avatar_url,
          html_url: user&.url || contributor.html_url
        }
      end
    end
  end
end
