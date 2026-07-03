# frozen_string_literal: true

class GitHubSearchTool < RubyLLM::Tool
  description "Search for GitHub users by name, optionally filtering by language (e.g., Ruby)"
  param :query, desc: "Search query (e.g., 'Firstname Lastname')"
  param :language, desc: "Programming language to filter by (e.g., 'Ruby')", required: false

  def execute(query:, language: nil)
    search_query = language ? "#{query} language:#{language}" : query
    result = client.search(search_query, per_page: 5)

    return {error: "No users found"} if result.nil? || result[:items].blank?

    {
      total_count: result[:total_count],
      users: result[:items].map do |user|
        {
          login: user[:login],
          name: user[:name],
          avatar_url: user[:avatar_url],
          html_url: user[:html_url],
          bio: user[:bio],
          location: user[:location],
          company: user[:company]
        }
      end
    }
  rescue => e
    {error: e.message}
  end

  private

  def client
    @client ||= GitHub::UserClient.new
  end
end
