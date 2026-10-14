# frozen_string_literal: true

module Yerba
  module Record
    module Querying
      extend ActiveSupport::Concern

      class_methods do
        attr_reader :path, :glob, :scalar_field, :nested_key, :order_by
        attr_writer :path, :glob, :base_path, :flatten, :scalar_field, :order_by

        delegate :count, :first, :last, :empty?, :each, :pluck, to: :all

        def base_path
          @base_path || superclass.try(:base_path)
        end

        def flatten
          @flatten || false
        end

        def all
          current_scope || (@all ||= Collection.new(record_class: self, sources: default_sources))
        end

        def where(...)
          all.where(...)
        end

        def in_file(path, document: nil)
          Collection.new(record_class: self, sources: [Collection::Source.new(path: path, document: document, mode: source_mode)])
        end

        def parse(content, path: nil)
          in_file(path, document: Yerba.parse(content.to_s))
        end

        def with_path(path)
          previous = @path
          @path = path.to_s

          unload!

          yield
        ensure
          @path = previous
          unload!
        end

        # Like ActiveRecord scopes: `scope :top_level, -> { where.missing(:parent) }`
        def scope(name, body)
          define_singleton_method(name) { |*args| all.instance_exec(*args, &body) }
        end

        # Makes `all` return `collection` inside the block. Collections call the model's class methods this way,
        # so `static_event.talks.pairs` runs `Static::Talk.pairs` over that one file.
        def scoping(collection)
          scopes = (Thread.current[:yerba_record_scopes] ||= {})
          previous = scopes[self]
          scopes[self] = collection

          yield
        ensure
          scopes[self] = previous
        end

        def current_scope
          Thread.current[:yerba_record_scopes]&.[](self)
        end

        def file_path
          return nil unless path

          base_path ? File.expand_path(path, base_path) : path
        end

        def unload!
          @all = nil
          @indexes = nil
        end

        def reset_loaded!(except: nil)
          if @all && except && @all.equal?(except)
            @all.reset!
          else
            unload!
          end
        end

        def source_mode
          if glob
            flatten ? :items : :single
          else
            scalar_field ? :scalar : :items
          end
        end

        private

        def default_sources
          if glob
            resolved_glob = base_path ? File.join(base_path, glob) : glob

            Dir.glob(resolved_glob).sort.map { |file| Collection::Source.new(path: file, mode: source_mode) }
          elsif path
            [Collection::Source.new(path: file_path, mode: source_mode)]
          else
            raise "Set self.path or self.glob on #{name}"
          end
        end
      end
    end
  end
end
