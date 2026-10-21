# frozen_string_literal: true

module DataFileAssertions
  def data_file_errors(file_path)
    Rails.autoloaders.main.eager_load_dir(Rails.root.join("app/models/static"))

    schema_errors = Static::Validators::Schema.new(file_path: file_path.to_s).errors.map(&:message)
    record_errors = Yerba::Record.validate_file(file_path).reject { |error| error.type == :unknown_speaker }.map(&:full_message)

    schema_errors + record_errors
  end

  def assert_valid_data_file(file_path, message = nil)
    errors = data_file_errors(file_path)

    assert_empty errors, message || errors.join(", ")
  end
end
