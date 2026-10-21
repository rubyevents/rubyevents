Rails.configuration.to_prepare do
  Yerba::Record::Base.root = Rails.root
  Yerba::Record::Base.schema_base_class = ApplicationSchema
  Yerba::Record::FileRecord.root = Rails.root

  Rails.autoloaders.main.eager_load_namespace(Static)
end
