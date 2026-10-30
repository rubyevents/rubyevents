require "test_helper"

class OrganizationLookupToolTest < ActiveSupport::TestCase
  include OrganizationToolFile

  test "finds organizations by slug, name, alias, alternate name and website" do
    assert_equal ["appsignal"], build_tool.execute(query: "AppSignal").map { |result| result[:slug] }
    assert_equal ["appsignal"], build_tool.execute(query: "app-signal").map { |result| result[:slug] }
    assert_equal ["typesense"], build_tool.execute(query: "typesense.org").map { |result| result[:slug] }
    assert_equal ["typesense"], build_tool.execute(query: "TypeSense").map { |result| result[:slug] }
    assert_equal %w[appsignal typesense], build_tool.execute(query: "s").map { |result| result[:slug] }.sort
  end

  test "returns the organization's fields" do
    result = build_tool.execute(query: "appsignal").first

    assert_equal "AppSignal", result[:name]
    assert_equal "https://www.appsignal.com", result[:website]
    assert_equal ["app-signal"], result[:aliases]
    assert_equal "company", result[:kind]
    assert_nil result[:description]
  end

  test "returns an empty list for no match" do
    assert_empty build_tool.execute(query: "nobody")
  end

  private

  def build_tool
    OrganizationLookupTool.new(organizations_file_path: @tmp_file.path)
  end
end
