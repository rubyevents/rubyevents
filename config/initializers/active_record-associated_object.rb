ActiveRecord::AssociatedObject.extend ActiveRecord::AssociatedObject::TokenGeneration = Module.new {
  def generates_token(expires_in:, &)
    purpose = attribute_name
    record.generates_token_for(purpose, expires_in:, &)

    define_singleton_method(:find_by_token) { find_by_token_for(purpose, it) }
    define_singleton_method(:find_by_token!) { find_by_token_for!(purpose, it) }

    define_method(:token) { record.generate_token_for(purpose) }
  end
}
