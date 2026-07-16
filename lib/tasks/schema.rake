namespace :schema do
  desc "Export all schemas as JSON Schemas to lib/schemas"
  task export: :environment do
    ApplicationSchema.schemas.each do |schema_class|
      puts "Exported #{schema_class} to #{schema_class.export!}"
    end
  end
end
