# frozen_string_literal: true

module Yerba
  module Record
    # The files in a directory that belongs to a record, like the images of an event (see `has_files`)
    class Files
      include Enumerable

      attr_reader :path

      def initialize(path, recursive: false, glob: nil)
        @path = Pathname.new(path)
        @recursive = recursive
        @glob = glob
      end

      def exist?
        path.directory?
      end

      def each(&block)
        return enum_for(:each) unless block

        return unless exist?

        path.glob(@glob || (@recursive ? "**/*" : "*")).select(&:file?).sort.each(&block)
      end

      def [](name)
        file = path.join(name)

        file if file.file?
      end

      def to_s
        path.to_s
      end

      def inspect
        "#<#{self.class.name} #{path}>"
      end
    end
  end
end
