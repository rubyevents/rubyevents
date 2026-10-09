require "test_helper"
require "generators/newsletter/newsletter_generator"

class NewsletterGeneratorTest < Rails::Generators::TestCase
  tests NewsletterGenerator
  destination Rails.root.join("tmp/generators")
  setup :prepare_destination

  # test "generator runs without errors" do
  #   assert_nothing_raised do
  #     run_generator ["arguments"]
  #   end
  # end
end
