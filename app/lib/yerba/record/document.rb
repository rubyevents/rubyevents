# frozen_string_literal: true

module Yerba
  module Record
    class Document
      attr_reader :path

      def initialize(path)
        @path = path.to_s
        @yerba = nil
      end

      def yerba
        @yerba ||= Yerba.parse_file(@path)
      end

      def values
        @values = yerba.value_at("") unless defined?(@values)
        @values
      end

      def reset_values!
        remove_instance_variable(:@values) if defined?(@values)
      end

      def root
        yerba.root
      end

      def exist?
        File.exist?(@path)
      end

      def changed?
        yerba.changed?
      end

      def save!
        yerba.save!(apply: true)
        reset_values!
      end

      def save_to!(path)
        @path = path.to_s
        yerba.save_to!(path.to_s)
        reset_values!
      end

      def self.create(path, content)
        document = Yerba::Document.from(content)
        document.save_to!(path)
        new(path)
      end

      def self.from(content)
        doc = allocate
        doc.instance_variable_set(:@path, nil)
        doc.instance_variable_set(:@yerba, Yerba::Document.from(content))
        doc
      end
    end
  end
end
