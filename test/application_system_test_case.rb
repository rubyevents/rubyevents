require "test_helper"

Capybara.register_driver :headless_chrome do |app|
  options = ::Selenium::WebDriver::Chrome::Options.new
  options.add_argument("--headless") unless ActiveModel::Type::Boolean.new.cast(ENV["HEADFUL"])
  options.add_argument("--window-size=1920,1080")

  client = Selenium::WebDriver::Remote::Http::Default.new
  client.read_timeout = 240

  Capybara::Selenium::Driver.new(app, browser: :chrome, capabilities: [options], http_client: client)
end

Capybara.javascript_driver = :headless_chrome

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  driven_by :selenium, using: :headless_chrome, screen_size: [1400, 1400]

  def sign_in_as(user)
    visit new_session_url
    fill_in :email, with: user.email
    fill_in :password, with: "Secret1*3*5*"
    click_on "Sign in"

    assert_current_path root_url
    user
  end

  def wait_for_turbo(timeout = 2)
    if has_css?(".turbo-progress-bar", visible: true, wait: 0.25.seconds)
      has_no_css?(".turbo-progress-bar", wait: timeout)
    end
  end

  def wait_for_turbo_stream_connected(streamable: nil)
    if streamable
      signed_stream_name = Turbo::StreamsChannel.signed_stream_name(streamable)
      assert_selector("turbo-cable-stream-source[connected][channel=\"Turbo::StreamsChannel\"][signed-stream-name=\"#{signed_stream_name}\"]", visible: :all)
    else
      assert_selector("turbo-cable-stream-source[connected][channel=\"Turbo::StreamsChannel\"]", visible: :all)
    end
  end
end

Capybara.default_max_wait_time = 5 # Set the wait time in seconds
