# frozen_string_literal: true

module Static
  # Speakers with closely matching names need a social handle to tell whether they're the same person
  #
  class SimilarSpeakerNamesValidator < FileErrorsValidator
    SIMILARITY_THRESHOLD = 0.85

    private

    def file_errors(records)
      speakers = Static::Speaker.in_file(records.first.file_path, document: records.first.document)

      speakers.near_duplicate_names(threshold: SIMILARITY_THRESHOLD).flat_map do |cluster|
        cluster.names.filter_map do |name|
          next if speakers.social_handle?(name)

          others = cluster.names - [name]
          message = "#{name.inspect} closely matches #{others.map(&:inspect).join(", ")} but has no social handle " \
            "(#{Static::Speaker::SOCIAL_HANDLE_FIELDS.join(", ")}). Add one to disambiguate whether they are the same person."

          [speakers.find_by(name: name), message, nil]
        end
      end
    end
  end
end
