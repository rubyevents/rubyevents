Rails.configuration.to_prepare do
  Yerba::Record::Base.root = Rails.root

  Rails.autoloaders.main.eager_load_namespace(Static)
end
