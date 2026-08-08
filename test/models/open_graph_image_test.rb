require "test_helper"
require "tempfile"

class OpenGraphImageTest < ActiveSupport::TestCase
  test "generate writes the screenshot to the output path" do
    output_file = Tempfile.new(["open-graph-image", ".png"])
    browser = mock_browser(screenshot_data: Base64.strict_encode64("png data"))
    open_graph_image = OpenGraphImage.new(output_path: output_file.path)

    result = nil
    open_graph_image.stub(:render_html, "<html></html>") do
      open_graph_image.stub(:sleep, nil) do
        result = open_graph_image.generate!(browser: browser)
      end
    end

    assert_equal Pathname(output_file.path), result
    assert_equal "png data", output_file.tap(&:rewind).read
    assert_mock browser
  ensure
    output_file&.close!
  end

  test "generate preserves the output and closes the browser when screenshotting fails" do
    output_file = Tempfile.new(["open-graph-image", ".png"])
    output_file.write("existing image")
    output_file.close
    browser = failing_browser
    open_graph_image = OpenGraphImage.new(output_path: output_file.path)

    assert_raises RuntimeError do
      open_graph_image.stub(:render_html, "<html></html>") do
        open_graph_image.stub(:sleep, nil) do
          open_graph_image.generate!(browser: browser)
        end
      end
    end

    assert_equal "existing image", File.binread(output_file.path)
    assert browser.quit_called
  ensure
    output_file&.close!
  end

  private

  def mock_browser(screenshot_data:)
    browser = Minitest::Mock.new
    browser.expect(:go_to, nil, [String])
    browser.expect(:screenshot, screenshot_data, [], format: :png, full: true)
    browser.expect(:quit, nil)
    browser
  end

  def failing_browser
    Struct.new(:quit_called) do
      def go_to(_url)
      end

      def screenshot(**)
        raise "screenshot failed"
      end

      def quit
        self.quit_called = true
      end
    end.new(false)
  end
end
