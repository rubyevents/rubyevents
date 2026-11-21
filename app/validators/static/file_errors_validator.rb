# frozen_string_literal: true

module Static
  # For checks that look at all records of a file together, like duplicate names in speakers.yml.
  # Subclasses return the file's errors from `file_errors(records)` as [record, message, at:] triples,
  # with a nil record for an error about the file as a whole.
  #
  class FileErrorsValidator < ActiveModel::Validator
    def validate(record)
      errors = Yerba::Record::Validations.cached(self.class, record.file_path) { file_errors(record.file_records.to_a) }
      first = Yerba::Record::Validations.cached(self.class, record.file_path, :first) { record.file_records.first }

      errors.each do |owner, message, at|
        if owner ? same?(owner, record) : same?(first, record)
          record.errors.add(:base, message, at: owner ? at : :file)
        end
      end
    end

    private

    def same?(one, other)
      one && one.selector == other.selector
    end
  end
end
