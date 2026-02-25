# -*- SkipSchemaAnnotations

class Event::InvolvementsFile < ActiveRecord::AssociatedObject
  include YAMLFile

  yaml_file "involvements.yml"

  def roles
    entries.map { |entry| entry["name"] }
  end

  def users_for_role(role)
    entry = entries.find { |e| e["name"] == role }
    return [] unless entry

    Array.wrap(entry["users"]).compact
  end

  def organisations_for_role(role)
    entry = entries.find { |e| e["name"] == role }
    return [] unless entry

    Array.wrap(entry["organisations"]).compact
  end

  def all_users
    entries.flat_map { |entry| Array.wrap(entry["users"]) }.compact
  end

  def all_organisations
    entries.flat_map { |entry| Array.wrap(entry["organisations"]) }.compact
  end
end
