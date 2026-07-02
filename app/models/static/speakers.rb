# frozen_string_literal: true

module Static
  class Speakers
    class << self
      def document
        @document ||= Yerba::Record::Document.new(Rails.root.join(SpeakersFile::SPEAKERS_PATH).to_s)
      end

      def all
        Yerba::Record::Collection.new(document: document, entry_class: Static::Speaker)
      end

      def find_by(name: nil, slug: nil, github: nil)
        index = speakers_file.index_by(:name)[name] if name
        index ||= speakers_file.index_by(:slug)[slug] if slug
        index ||= speakers_file.index_by(:github)[github] if github

        if index.nil? && name
          speakers_file.document.value_at("").each_with_index do |entry, i|
            next unless entry.is_a?(Hash)

            if Array(entry["aliases"]).any? { |a| a.respond_to?(:key?) && a["name"] == name }
              index = i
              break
            end
          end
        end

        return nil unless index

        Static::Speaker.new(document: document, index: index)
      end

      def find_or_create_by(name:)
        find_by(name: name) || create(name: name)
      end

      def create(name:, github: "", slug: nil, **attributes)
        slug ||= name.parameterize

        document.yerba << {name: name, github: github, slug: slug, **attributes}
        document.yerba.sort(by: :name)
        document.save!

        reset!

        find_by(name: name)
      end

      def reset!
        @document = nil
        @speakers_file = nil
      end

      private

      def speakers_file
        @speakers_file ||= Static::SpeakersFile.new
      end
    end
  end
end
