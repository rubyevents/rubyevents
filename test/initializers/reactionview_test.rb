require "test_helper"

class ReactionviewTest < ActiveSupport::TestCase
  test "disables template instrumentation" do
    config = ReActionView.config
    original_debug_mode = config.debug_mode
    original_instrumentation_enabled = config.instrumentation.enabled
    config.instrumentation.enabled = true

    load Rails.root.join("config/initializers/reactionview.rb")

    refute config.instrumentation.enabled
  ensure
    config.debug_mode = original_debug_mode
    config.instrumentation.enabled = original_instrumentation_enabled
  end
end
