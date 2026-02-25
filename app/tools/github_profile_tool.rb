# frozen_string_literal: true

class GitHubProfileTool < RubyLLM::Tool
  description "Fetch GitHub profile information by username/handle"
  param :username, desc: "GitHub username/handle (without @)"

  def execute(username:)
    handle = username.delete_prefix("@")
    profile = client.profile(handle)

    return {error: "User not found"} unless profile

    profile.to_h
  rescue => e
    {error: e.message}
  end

  private

  def client
    @client ||= GitHub::UserClient.new
  end
end
