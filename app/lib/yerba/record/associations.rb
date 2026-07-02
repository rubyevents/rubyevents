# frozen_string_literal: true

module Yerba
  module Record
    module Associations
      extend ActiveSupport::Concern

      class_methods do
        #   belongs_to :series, foreign_key: :series_slug
        #   belongs_to :event
        #   belongs_to :event, class_name: "Static::Event"
        def belongs_to(name, class_name: nil, foreign_key: nil)
          class_name ||= infer_class_name(name)

          unless foreign_key
            define_method(:"#{name}_slug") do
              relative_file_path&.split("/")&.[](-2)
            end
          end

          define_method(name) do
            slug_value = send(foreign_key || :"#{name}_slug")
            return nil unless slug_value

            klass = class_name.is_a?(String) ? class_name.constantize : class_name

            begin
              klass.find_by_slug(slug_value)
            rescue
              klass.find_by(slug: slug_value)
            end
          end
        end

        #   has_many :events, foreign_key: :series_slug
        #   has_many :videos, in_file: "videos.yml"
        def has_many(name, class_name: nil, foreign_key: nil, in_file: nil)
          class_name ||= infer_class_name(name, singularize: true)

          if in_file
            define_method(name) do
              path = File.join(event_dir, in_file)
              document = Yerba::Record::Document.new(path)
              klass = class_name.is_a?(String) ? class_name.constantize : class_name

              Yerba::Record::Collection.new(document: document, entry_class: klass)
            end
          else
            define_method(name) do
              klass = class_name.is_a?(String) ? class_name.constantize : class_name
              slug_value = slug

              klass.all.select { |record| record.send(foreign_key) == slug_value }
            end
          end
        end

        #   has_one :venue, in_file: "venue.yml"
        #   has_one :series, through: :event
        def has_one(name, in_file: nil, through: nil, class_name: nil)
          if through
            define_method(name) { send(through)&.send(name) }
            return
          end

          class_name ||= infer_class_name(name)

          define_method(name) do
            path = File.join(event_dir, in_file)
            return nil unless File.exist?(path)

            document = Yerba::Record::Document.new(path)
            klass = class_name.is_a?(String) ? class_name.constantize : class_name

            klass.new(document: document)
          end

          define_method(:"build_#{name}") do |**attributes|
            path = File.join(event_dir, in_file)
            klass = class_name.is_a?(String) ? class_name.constantize : class_name

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
