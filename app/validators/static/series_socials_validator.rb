# frozen_string_literal: true

module Static
  # Socials that are the same on the event and its series belong on the series only:
  #
  #   validates_with Static::SeriesSocialsValidator, duplicated: %w[twitter github], missing: %w[twitter]
  #
  # `duplicated:` fields are removed from the event when the series has the same value, `missing:`
  # fields move to the series when it doesn't have one (unless a sibling event has another value).
  #
  class SeriesSocialsValidator < ActiveModel::Validator
    def validate(event)
      duplicated_fields(event).each do |field|
        event.errors.add(field, %((#{event[field]}) is already defined in series.yml — remove it from event.yml and keep it on series.yml. Run `bin/rails validate:fix` to remove it.))
      end

      missing_fields(event).each do |field|
        event.errors.add(field, %((#{event[field]}) is not defined in series.yml — move it to series.yml so every event in the series shares it. Run `bin/rails validate:fix` to move it.))
      end
    end

    def fix(event)
      duplicated = duplicated_fields(event)
      duplicated.each { |field| event.delete(field) }

      missing = missing_fields(event).reject { |field| conflicting_sibling?(event, field) }

      if missing.any?
        missing.each do |field|
          event.series[field] = event[field]
          event.delete(field)
        end

        event.series.save!(validate: false)
      end

      duplicated.size + missing.size
    end

    private

    def duplicated_fields(event)
      series = event.series
      return [] unless series

      Array(options[:duplicated]).select do |field|
        value = normalize(event[field])
        value.present? && value == normalize(series[field])
      end
    end

    def missing_fields(event)
      series = event.series
      return [] unless series

      Array(options[:missing]).select { |field| event[field].to_s.strip.present? && series[field].to_s.strip.blank? }
    end

    def conflicting_sibling?(event, field)
      value = normalize(event[field])

      event.series.events.any? do |sibling|
        next false if sibling.file_path == event.file_path

        sibling_value = normalize(sibling[field])
        sibling_value.present? && sibling_value != value
      end
    end

    def normalize(value)
      value.to_s.strip.downcase.delete_prefix("@").delete_suffix("/")
    end
  end
end
