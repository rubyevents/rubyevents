require "test_helper"

class Recurring::FetchContributorsJobTest < ActiveJob::TestCase
  test "should fetch and sync contributors" do
    VCR.use_cassette("recurring/fetch_contributors_job", match_requests_on: [:method]) do
      Contributor.destroy_all
      assert_equal 0, Contributor.count

      Recurring::FetchContributorsJob.new.perform

      assert Contributor.count > 0, "Should have synced contributors from GitHub"

      # Verify data structure
      contributor = Contributor.first
      assert_not_nil contributor.login
      assert_not_nil contributor.avatar_url
      assert_not_nil contributor.html_url
    end
  end
end
