Rails.configuration.to_prepare do
  Rails.autoloaders.main.eager_load_namespace(Static)
end
