# frozen_string_literal: true

module Yerba
  module Record
    module Associations
      extend ActiveSupport::Concern

      def self.nested_owners
        @nested_owners ||= {}
      end

      private

      # The path of an associated record shares the named segments of this record's path. Its `:id` is this
      # record's `:<association>_id` (a talk's `:event_id` for its event), and its `:<model>_id` is this
      # record's `:id` (an event's `:id` for its talks).
      def association_path_params(klass, name)
        own_key = :"#{self.class.name.demodulize.underscore}_id"

        klass.path_pattern&.names.to_a.to_h do |segment|
          value = if segment == :id
            path_params[:"#{name}_id"]
          elsif path_params.key?(segment)
            path_params[segment]
          elsif segment == own_key
            path_params[:id]
          end

          [segment, value]
        end
      end

      class_methods do
        #   belongs_to :series, foreign_key: :series_slug
        #   belongs_to :event
        #   belongs_to :event, class_name: "Static::Event"
        def belongs_to(name, class_name: nil, foreign_key: nil)
          class_name ||= infer_class_name(name)

          unless foreign_key
            define_method(:"#{name}_slug") do
              path_params[:"#{name}_id"]
            end
          end

          define_method(name) do
            klass = class_name.is_a?(String) ? class_name.constantize : class_name

            unless foreign_key
              path = klass.path_for(association_path_params(klass, name), root: path_root)

              return klass.find_by_file_path(path) || (klass.in_file(path).first if path && File.exist?(path))
            end

            slug_value = send(foreign_key)
            return nil unless slug_value

            begin
              klass.find_by_slug(slug_value)
            rescue
              klass.find_by(slug: slug_value)
            end
          end
        end

        #   has_many :events, foreign_key: :series_slug
        #   has_many :talks
        #   has_many :talks, nested: true
        def has_many(name, class_name: nil, foreign_key: nil, nested: false)
          class_name ||= infer_class_name(name, singularize: true)

          if nested
            nested_class_name = class_name.is_a?(String) ? class_name : class_name.name

            if nested_class_name == self.name
              @nested_key = name.to_s
            else
              Associations.nested_owners[nested_class_name] = [self.name, name]
            end

            define_method(name) do
              @nested_collections ||= {}

              @nested_collections[name] ||= begin
                klass = class_name.is_a?(String) ? class_name.constantize : class_name

                if new_record? || parsed_selector.nil?
                  Collection.new(record_class: klass, records: [])
                else
                  Collection.new(record_class: klass, document: document, selector: parsed_selector.join(name.to_s), parent: self)
                end
              end
            end
          elsif foreign_key
            define_method(name) do
              klass = class_name.is_a?(String) ? class_name.constantize : class_name
              slug_value = slug

              klass.all.where { |record| record.send(foreign_key) == slug_value }
            end
          else
            define_method(name) do
              klass = class_name.is_a?(String) ? class_name.constantize : class_name
              path = klass.path_for(association_path_params(klass, name), root: path_root)

              path ? klass.in_file(path) : Collection.new(record_class: klass, records: [])
            end
          end
        end

        # A directory named by segments of the record's path or by its attributes. It moves when they change.
        #
        # With a wildcard in the last segment, the files matching it, which move one by one.
        #
        #   has_files :images, "app/assets/images/events/:series_id/:id"
        #   has_files :thumbnails, "app/assets/images/thumbnails/:id", recursive: true
        #   has_files :stickers, "app/assets/images/events/:series_id/:id/sticker*.webp"
        def has_files(name, pattern, recursive: false)
          pattern = PathPattern.new(pattern)
          file_associations[name.to_sym] = {pattern: pattern, directory: !pattern.wildcard?, glob: pattern.wildcard?}

          define_method(name) do
            if pattern.wildcard?
              glob = pattern.expand_glob(segment_values(pattern, path_params) { |key| self[key] })
              next unless glob

              glob = File.expand_path(glob, path_root.to_s)
              Files.new(File.dirname(glob), glob: File.basename(glob))
            else
              path = file_association_path(name)

              Files.new(path, recursive: recursive) if path
            end
          end
        end

        # A file named by segments of the record's path or by its attributes, as a `Pathname`. It moves when they change.
        # A `**` finds the file in any subdirectory.
        #
        #   has_file :avatar, "app/assets/images/events/:series_id/:id/avatar.webp"
        #   has_file :thumbnail, "app/assets/images/thumbnails/:event_id/**/:video_id.webp"
        def has_file(name, pattern)
          file_associations[name.to_sym] = {pattern: PathPattern.new(pattern), directory: false}

          define_method(name) do
            path = file_association_path(name)

            Pathname.new(path) if path
          end
        end

        def file_associations
          @file_associations ||= {}
        end

        #   has_one :venue
        #   has_one :series, through: :event
        def has_one(name, through: nil, class_name: nil)
          if through
            define_method(name) { send(through)&.send(name) }
            return
          end

          class_name ||= infer_class_name(name)

          define_method(name) do
            klass = class_name.is_a?(String) ? class_name.constantize : class_name
            path = klass.path_for(association_path_params(klass, name), root: path_root)

            klass.in_file(path).first if path && File.exist?(path)
          end

          define_method(:"build_#{name}") do |**attributes|
            klass = class_name.is_a?(String) ? class_name.constantize : class_name
            path = klass.path_for(association_path_params(klass, name), root: path_root)

            record = klass.new(**attributes)
            record.define_singleton_method(:persist_path) { path }
            record
          end

          define_method(:"create_#{name}") do |**attributes|
            record = send(:"build_#{name}", **attributes)
            record.save!
            record
          end
        end

        private

        def infer_class_name(name, singularize: false)
          class_name = name.to_s
          class_name = class_name.singularize if singularize
          class_name = class_name.classify

          namespace = self.name.deconstantize
          "#{namespace}::#{class_name}"
        end
      end
    end
  end
end
