# frozen_string_literal: true

module YAMLFile
  extend ActiveSupport::Concern

  class_methods do
    def yaml_file(filename, data_method: :file)
      define_method(:file_name) { filename }
      define_method(:data_method_name) { data_method }
    end
  end

  def file_path
    record.data_folder.join(file_name)
  end

  def exist?
    file_path.exist?
  end

  def file
    return {} unless exist?

    @file ||= YAML.load_file(file_path) || {}
  end

  def entries
    return [] unless exist?

    @entries ||= YAML.load_file(file_path) || []
  end

  def reload
    @file = nil
    @entries = nil

    self
  end
end
