require "test_helper"
require "webrick"
require "socket"

class DownloadSponsorsTest < ActiveSupport::TestCase
  def self.find_free_port
    server = TCPServer.new("127.0.0.1", 0)
    port = server.addr[1]
    server.close
    port
  end

  def setup
    @download_sponsors = DownloadSponsors.new

    # Start a local test server
    @port = self.class.find_free_port
    @base_url = "http://127.0.0.1:#{@port}"

    @server_thread = Thread.new do
      @server = WEBrick::HTTPServer.new(Port: @port, Logger: WEBrick::Log.new(File::NULL), AccessLog: [])
      @server.mount_proc "/" do |req, res|
        handle_test_request(req, res)
      end
      @server.start
    end

    # Wait for server to start
    sleep 0.1
  end

  def teardown
    @server&.shutdown
    @server_thread&.kill
  end

  private

  def handle_test_request(req, res)
    res.status = 200
    res["Content-Type"] = "text/html"
    res.body = @current_html_content || "<html><body></body></html>"
  end

  test "find_sponsor_page returns sponsor link when found" do
    @current_html_content = <<~HTML
      <html>
        <body>
          <a href="/about">About Us</a>
          <a href="/sponsors">Our Sponsors</a>
          <a href="/contact">Contact</a>
        </body>
      </html>
    HTML

    result = @download_sponsors.find_sponsor_page(@base_url)

    assert_equal "#{@base_url}/sponsors", result
  end

  test "find_sponsor_page returns nil when no sponsor link found" do
    @current_html_content = <<~HTML
      <html>
        <body>
          <a href="/about">About Us</a>
          <a href="/contact">Contact</a>
          <a href="/team">Our Team</a>
        </body>
      </html>
    HTML

    result = @download_sponsors.find_sponsor_page(@base_url)

    assert_nil result
  end

  test "find_sponsor_page finds link by href containing sponsor" do
    @current_html_content = <<~HTML
      <html>
        <body>
          <a href="/about">About Us</a>
          <a href="/sponsorship-info">Learn More</a>
          <a href="/contact">Contact</a>
        </body>
      </html>
    HTML

    result = @download_sponsors.find_sponsor_page(@base_url)

    assert_equal "#{@base_url}/sponsorship-info", result
  end

  test "find_sponsor_page finds link by text containing sponsor" do
    @current_html_content = <<~HTML
      <html>
        <body>
          <a href="/about">About Us</a>
          <a href="/partners">Become a Sponsor</a>
          <a href="/contact">Contact</a>
        </body>
      </html>
    HTML

    result = @download_sponsors.find_sponsor_page(@base_url)

    assert_equal "#{@base_url}/partners", result
  end

  test "find_sponsor_page ignores fragment links" do
    @current_html_content = <<~HTML
      <html>
        <body>
          <a href="/about">About Us</a>
          <a href="#sponsors">Sponsors</a>
          <a href="/contact">Contact</a>
        </body>
      </html>
    HTML

    result = @download_sponsors.find_sponsor_page(@base_url)

    assert_nil result
  end

  test "find_sponsor_page ignores links with images" do
    @current_html_content = <<~HTML
      <html>
        <body>
          <a href="/about">About Us</a>
          <a href="/sponsors">
            <img src="sponsors-logo.png" alt="Sponsors">
            Sponsors
          </a>
          <a href="/contact">Contact</a>
        </body>
      </html>
    HTML

    result = @download_sponsors.find_sponsor_page(@base_url)

    assert_nil result
  end

  test "find_sponsor_page handles relative URLs correctly" do
    @current_html_content = <<~HTML
      <html>
        <body>
          <a href="/about">About Us</a>
          <a href="sponsors.html">Our Sponsors</a>
          <a href="/contact">Contact</a>
        </body>
      </html>
    HTML

    result = @download_sponsors.find_sponsor_page("#{@base_url}/conference")

    assert_equal "#{@base_url}/sponsors.html", result
  end
end
