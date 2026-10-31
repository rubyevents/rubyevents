# frozen_string_literal: true

module Static
  module Validators
    # Every reference in the files matching PATTERNS must be an entry (or alias) in the curated file of `model`,
    # like speaker names in data/speakers.yml. Subclasses name the model, its missing references, how to add them,
    # and the error message.
    class ReferenceExists
      def initialize(file_path:, document: nil)
        @file_path = file_path.to_s.sub("#{Rails.root}/", "")
      end

      def applicable?
        return false unless File.exist?(@file_path)

        self.class::PATTERNS.any? do |pattern|
          File.fnmatch?(pattern, @file_path, File::FNM_PATHNAME | File::FNM_DOTMATCH)
        end
      end

      def errors
        return [] unless applicable?

        self.class.errors.select { |error| error.file_path == @file_path }
      end

      def fix
        return if errors.empty?

        added = self.class.add_missing
        self.class.model.save!
        self.class.reset!

        {changed: added.size, file_path: @file_path}
      end

      class << self
        def errors
          @errors ||= missing_references(model.in_file(model.file_path)).map do |reference|
            Static::Validators::Error.new(message(reference), file_path: reference.file_path || "", line: reference.line || 1)
          end
        end

        def warmup
          errors
        end

        def reset!
          @errors = nil
        end
      end
    end
  end
end
