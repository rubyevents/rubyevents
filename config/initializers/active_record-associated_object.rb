ActiveRecord::AssociatedObject.extend ActiveRecord::AssociatedObject::TokenGeneration = Module.new {
  # A wrapper around `generates_token_for` on the associated record.
  #
  #   class Post::Publisher < ActiveRecord::AssociatedObject
  #     generates_token(expires_in: 15.minutes) { post.published? }
  #   end
  #
  # Here, we internally call `Post.generates_token_for(:publisher)`.
  #
  # However, we ensure the block is `instance_eval`'ed on the associated `publisher` object, not the `post`.
  #
  # We also generate these wrapping methods:
  #
  #   publisher.token # => post.generate_token_for :publisher
  #   Post::Publisher.find_by_token(token)  # => Post.find_by_token_for(:publisher, token)
  #   Post::Publisher.find_by_token!(token) # => Post.find_by_token_for!(:publisher, token)
  def generates_token(expires_in:, &)
    purpose = attribute_name
    record.generates_token_for(purpose, expires_in:) { public_send(purpose).instance_eval(&) }

    define_singleton_method(:find_by_token) { find_by_token_for(purpose, it) }
    define_singleton_method(:find_by_token!) { find_by_token_for!(purpose, it) }

    define_method(:token) { record.generate_token_for(purpose) }
  end
}
