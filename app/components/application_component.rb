# frozen_string_literal: true

class ApplicationComponent < ViewComponent::Base
  extend Dry::Initializer

  attr_accessor :attributes
  option :display, default: proc { true }

  def initialize(*, **options)
    super
    defined_option_keys = self.class.dry_initializer.options.map(&:source)
    self.attributes = options.except(*defined_option_keys)
  end

  def render?
    display
  end
end
