# frozen_string_literal: true

module Generators
  module YerbaActions
    def yaml_upsert(path, attributes, identity:, selector: nil)
      destination = "#{relative_to_original_destination_root(path.to_s)} (#{identity.map { |key, value| "#{key}: #{value}" }.join(", ")})"

      unless File.exist?(path.to_s)
        if behavior == :invoke && !options[:pretend]
          raise Thor::Error, "#{path} does not exist. Create it (e.g. with `template`) before calling yaml_upsert."
        end

        return say_status((behavior == :invoke) ? :insert : :skip, destination)
      end

      document = Yerba.parse_file(path.to_s)
      target = selector ? document.fetch(selector) : document
      existing = target.find_by(**identity)

      if behavior == :invoke
        existing&.delete
        target << attributes

        say_status(existing ? :update : :insert, destination, existing ? :yellow : :green)
        document.save!(apply: true) unless options[:pretend]
      elsif existing
        existing.delete

        say_status(:remove, destination, :red)
        document.save!(apply: true) unless options[:pretend]
      else
        say_status(:skip, destination, :yellow)
      end
    end

    def yaml_set(path, selector, value)
      return unless behavior == :invoke

      say_status(:yaml_set, "#{relative_to_original_destination_root(path.to_s)} #{selector}")
      return if options[:pretend]

      document = Yerba.parse_file(path.to_s)
      document[selector] = value
      document.save!(apply: true)
    end

    def yaml_remove(path, selector)
      return unless behavior == :invoke

      say_status(:yaml_remove, "#{relative_to_original_destination_root(path.to_s)} #{selector}", :red)
      return if options[:pretend]

      document = Yerba.parse_file(path.to_s)
      document.delete(selector)
      document.save!(apply: true)
    end
  end
end
