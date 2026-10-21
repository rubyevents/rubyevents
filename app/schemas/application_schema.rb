# frozen_string_literal: true

class ApplicationSchema < Schematist::Schema
  class << self
    attr_accessor :record_class
  end

  def self.to_s
    name || super
  end

  def self.inspect
    name || super
  end

  def self.schemas
    Rails.autoloaders.main.eager_load_dir(Rails.root.join("app/schemas"))
    Rails.autoloaders.main.eager_load_namespace(Static)

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

    @data_file || ("**/#{record_class.path_pattern.glob}" if record_class&.path && !record_class.scalar_field)
  end

  def self.data_file_selector
    return @data_file_selector if @data_file

    "[]" if record_class&.source_mode == :items
  end

  def self.matches?(file_path)
    data_file.present? && File.fnmatch?(data_file, file_path.to_s, File::FNM_PATHNAME | File::FNM_DOTMATCH)
  end

  def self.json_schema
    new.to_json_schema.as_json
  end

  def self.exported_json
    "#{JSON.pretty_generate(json_schema)}\n"
  end

  def self.export!
    export_path.write(exported_json)

    export_path
  end

  def self.export_path
    Rails.root.join("lib/schemas/#{name.underscore}.json")
  end

  def self.in_sync?
    export_path.exist? && export_path.read == exported_json
  end
end
