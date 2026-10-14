# -*- SkipSchemaAnnotations

class Event::DataFile < ActiveRecord::AssociatedObject
  def self.data_file(association, file_name:)
    define_method(:static_association_name) { association }
    define_method(:file_name) { file_name }
  end

  def file_path
    return record.data_folder.join(file_name) unless static_event

    Pathname.new(static_event.event_dir).join(file_name)
  end

  def exist?
    case static_association
    when nil
      false
    when Yerba::Record::Collection
      static_association.exist?
    else
      true
    end
  end

  def file
    return {} unless exist?

    @file ||= static_association.attributes
  end

  def entries
    return [] unless exist?

    @entries ||= static_association.where.missing(:parent).map(&:attributes)
  end

  def reload
    @static_event = nil
    @file = nil
    @entries = nil

    remove_instance_variable(:@static_association) if defined?(@static_association)

    self
  end

  private

  def static_event
    @static_event ||= Static::Event.find_by_slug(record.slug)
  end

  def static_association
    return @static_association if defined?(@static_association)

    @static_association = static_event&.public_send(static_association_name)
  end
end
