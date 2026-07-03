# frozen_string_literal: true

class InvolvementSchema < RubyLLM::Schema
  string :name, description: "Role or involvement type (e.g., 'Organizer', 'Program Committee member')"
  array :users, of: :string, description: "Person names involved in this role", required: false
  array :organisations, of: :string, description: "Organization names involved in this role", required: false
end
