# frozen_string_literal: true

module Static
  class InvolvementNameValidator < ActiveModel::Validator
    def validate(involvement)
      name = involvement["name"]

      return unless name.present? && name.singularize != name

      involvement.errors.add(:base, "'#{name}' should be singular", at: "name")
    end
  end
end
