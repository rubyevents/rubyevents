module Todoable
  extend ActiveSupport::Concern

  def todos
    Todo.for_path(todos_data_path, prefix: todos_file_prefix)
  end

  def todos_count
    todos.size
  end

  private

  def todos_data_path
    raise NotImplementedError, "Subclasses must implement #todos_data_path"
  end

  def todos_file_prefix
    raise NotImplementedError, "Subclasses must implement #todos_file_prefix"
  end
end
