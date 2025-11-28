require "test_helper"
class YouTube::ChannelsTest < ActiveSupport::TestCase
  setup do
  end

  test "should retreive the channel id from the user name" do
    VCR.use_cassette("youtube/channels", match_requests_on: [:method]) do
      channel_id = YouTube::Channels.new.id_by_name(channel_name: "confreaks")
      assert_equal "UCWnPjmqvljcafA0z2U1fwKQ", channel_id
    end
  end

  test "should retreive the channel id from the user name with dash" do
    VCR.use_cassette("youtube/channels-scrapping", match_requests_on: [:method]) do
      channel_id = YouTube::Channels.new.id_by_name(channel_name: "paris-rb")
      assert_equal "UCFKE6QHGPAkISMj1SQdqnnw", channel_id
    end
  end
end
