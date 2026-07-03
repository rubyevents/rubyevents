namespace :schema do
  # This is to support validating schemas using the YAML language tools
  # aka the VS Code YAML extension
  desc "Export all schemas as JSON Schemas to lib/schemas"
  task export: :environment do
    require "fileutils"

    schema_files = Dir.glob(Rails.root.join("app/schemas/*_schema.rb"))
    schema_files.each do |file|
      base = File.basename(file, ".rb")
      schema_class = base.camelize.constantize
      json_schema_path = Rails.root.join("lib/schemas/#{base}.json")
      json_schema = JSON.pretty_generate(schema_class.new.to_json_schema[:schema])
      File.write(json_schema_path, json_schema)
      puts "Exported #{schema_class} to #{json_schema_path}"
    end
  end
end
