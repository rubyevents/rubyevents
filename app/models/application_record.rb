class ApplicationRecord < ActiveRecord::Base
  primary_abstract_class

  # User.first.mailer # => User::Mailer.with(user:)
  def mailer
    self.class::Mailer.with(model_name.element.to_sym => self)
  end
end
