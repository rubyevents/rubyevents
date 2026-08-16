# frozen_string_literal: true

class ApplicationSchema < RubyLLM::Schema
  def self.schemas
    Rails.autoloaders.main.eager_load_dir(Rails.root.join("app/schemas"))

    registry.sort_by(&:name)
  end

  def self.inherited(schema)
    super

    ApplicationSchema.registry.reject! { |registered| registered.name == schema.name }
    ApplicationSchema.registry << schema
  end

  def self.registry
    @registry ||= []
  end

  def self.data_file(pattern = nil, selector: nil)
    if pattern
      @data_file = pattern
      @data_file_selector = selector
    end

    @data_file
  end

  def self.data_file_selector
    @data_file_selector
  end

  def self.matches?(file_path)
    data_file.present? && File.fnmatch?(data_file, file_path.to_s, File::FNM_PATHNAME)
  end

  def self.json_schema
    new.to_json_schema[:schema].as_json
  end

  def self.export!
    export_path.write(JSON.pretty_generate(json_schema))

    export_path
  end

  def self.export_path
    Rails.root.join("lib/schemas/#{name.underscore}.json")
  end

  def self.in_sync?
    export_path.exist? && export_path.read == JSON.pretty_generate(json_schema)
  end
end
