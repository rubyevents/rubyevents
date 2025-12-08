# == Schema Information
#
# Table name: rollups
# Database name: primary
#
#  id         :integer          not null, primary key
#  dimensions :json             not null, uniquely indexed => [name, interval, time]
#  interval   :string           not null, uniquely indexed => [name, time, dimensions]
#  name       :string           not null, uniquely indexed => [interval, time, dimensions]
#  time       :datetime         not null, uniquely indexed => [name, interval, dimensions]
#  value      :float
#
# Indexes
#
#  index_rollups_on_name_and_interval_and_time_and_dimensions  (name,interval,time,dimensions) UNIQUE
#
class Rollup < ApplicationRecord
  # this Rollup model is heavily inspired from ankane/rollup gem but adapted so that we can
  # use Sqlite
  #
  validates :name, presence: true
  validates :interval, presence: true
  validates :time, presence: true

  scope :with_dimensions, ->(dimensions) do
    relation = self
    dimensions.each do |k, v|
      relation = if v.nil?
        relation.where("json_extract(dimensions, ?) IS NULL", "$.#{k}")
      elsif v.is_a?(Array)
        relation.where("json_extract(dimensions, ?) IN (?)", "$.#{k}", v.map { |vi| vi.as_json.to_s })
      else
        relation.where("json_extract(dimensions, ?) = ?", "$.#{k}", v.as_json.to_s)
      end
    end
    relation
  end

  class << self
    attr_accessor :week_start
    attr_writer :time_zone
  end
  self.week_start = :monday

  class << self
    # do not memoize so Time.zone can change
    def time_zone
      (defined?(@time_zone) && @time_zone) || Time.zone || ActiveSupport::TimeZone["Etc/UTC"]
    end

    def series(name, interval: "day", dimensions: {})
      relation = where(name: name, interval: interval)
      relation = relation.where(dimensions: dimensions) if dimensions.any?

      # use select_all due to incorrect casting with pluck
      sql = relation.order(:time).select(Utils.time_sql(interval), :value).to_sql
      result = connection_pool.with_connection { |c| c.select_all(sql) }.rows

      make_series(result, interval)
    end

    def list
      select(:name, :interval).distinct.order(:name, :interval).map do |r|
        {name: r.name, interval: r.interval}
      end
    end

    # TODO maybe use in_batches
    def rename(old_name, new_name)
      where(name: old_name).update_all(name: new_name)
    end

    private

    def make_series(result, interval)
      series = {}
      if Utils.date_interval?(interval)
        result.each do |row|
          series[row[0].to_date] = (series[row[0].to_date] || 0) + row[1]
        end
      else
        time_zone = Rollup.time_zone
        if result.any? && result[0][0].is_a?(Time)
          result.each do |row|
            series[row[0].in_time_zone(time_zone)] = (series[row[0].in_time_zone(time_zone)] || 0) + row[1]
          end
        else
          utc = ActiveSupport::TimeZone["Etc/UTC"]
          result.each do |row|
            # row can be time or string
            series[utc.parse(row[0]).in_time_zone(time_zone)] = (series[utc.parse(row[0]).in_time_zone(time_zone)] || 0) + row[1]
          end
        end
      end
      series
    end
  end

  # feels cleaner than overriding _read_attribute
  def inspect
    if Utils.date_interval?(interval)
      super.sub(/time: "[^"]+"/, "time: \"#{time.to_formatted_s(:db)}\"")
    else
      super
    end
  end

  def time
    if Utils.date_interval?(interval) && !time_before_type_cast.nil?
      if time_before_type_cast.is_a?(Time)
        time_before_type_cast.utc.to_date
      else
        Date.parse(time_before_type_cast.to_s)
      end
    else
      super
    end
  end

  class Aggregator
    def initialize(klass)
      @klass = klass # or relation
    end

    def rollup(name, column: nil, interval: "day", dimension_names: nil, time_zone: nil, current: nil, last: nil, clear: false, range: nil, &block)
      raise "Name can't be blank" if name.blank?

      column ||= @klass.rollup_column || :created_at
      # Groupdate 6+ validates, but keep this for now for additional safety
      # no need to quote/resolve column here, as Groupdate handles it
      column = validate_column(column)

      relation = perform_group(name, column: column, interval: interval, time_zone: time_zone, current: current, last: last, clear: clear, range: range)
      result = perform_calculation(relation, &block)

      dimension_names = set_dimension_names(dimension_names, relation)
      records = prepare_result(result, name, dimension_names, interval)

      maybe_clear(clear, name, interval) do
        save_records(records) if records.any?
      end
    end

    # basic version of Active Record disallow_raw_sql!
    # symbol = column (safe), Arel node = SQL (safe), other = untrusted
    # matches table.column and column
    def validate_column(column)
      unless column.is_a?(Symbol) || column.is_a?(Arel::Nodes::SqlLiteral)
        column = column.to_s
        unless /\A\w+(\.\w+)?\z/i.match?(column)
          raise ActiveRecord::UnknownAttributeReference, "Query method called with non-attribute argument(s): #{column.inspect}. Use Arel.sql() for known-safe values."
        end
      end
      column
    end

    def perform_group(name, column:, interval:, time_zone:, current:, last:, clear:, range:)
      raise ArgumentError, "Cannot use last and range together" if last && range
      raise ArgumentError, "Cannot use last and clear together" if last && clear
      raise ArgumentError, "Cannot use range and clear together" if range && clear
      raise ArgumentError, "Cannot use range and current together" if range && !current.nil?

      current = true if current.nil?
      time_zone = Rollup.time_zone if time_zone.nil?

      gd_options = {
        current: current
      }

      # make sure Groupdate global options aren't applied
      gd_options[:time_zone] = time_zone
      gd_options[:week_start] = Rollup.week_start if interval.to_s == "week"
      gd_options[:day_start] = 0 if Utils.date_interval?(interval)

      if last
        gd_options[:last] = last
      elsif range
        gd_options[:range] = range
        gd_options[:expand_range] = true
        gd_options.delete(:current)
      elsif !clear
        # if no rollups, compute all intervals
        # if rollups, recompute last interval
        max_time = Rollup.unscoped.where(name: name, interval: interval).maximum(Utils.time_sql(interval))
        if max_time
          # for MySQL on Ubuntu 18.04 (and likely other platforms)
          if max_time.is_a?(String)
            utc = ActiveSupport::TimeZone["Etc/UTC"]
            max_time =
              if Utils.date_interval?(interval)
                max_time.to_date
              else
                t = utc.parse(max_time)
                t = t.in_time_zone(time_zone) if time_zone
                t
              end
          end

          # aligns perfectly if time zone doesn't change
          # if time zone does change, there are other problems besides this
          gd_options[:range] = max_time..
        end
      end

      # intervals are stored as given
      # we don't normalize intervals (i.e. change 60s -> 1m)
      case interval.to_s
      when "hour", "day", "week", "month", "quarter", "year"
        @klass.group_by_period(interval, column, **gd_options)
      when /\A\d+s\z/
        @klass.group_by_second(column, n: interval.to_i, **gd_options)
      when /\A\d+m\z/
        @klass.group_by_minute(column, n: interval.to_i, **gd_options)
      else
        raise ArgumentError, "Invalid interval: #{interval}"
      end
    end

    def set_dimension_names(dimension_names, relation)
      groups = relation.group_values[0..-2]

      if dimension_names
        if dimension_names.size != groups.size
          raise ArgumentError, "Expected dimension_names to be size #{groups.size}, not #{dimension_names.size}"
        end
        dimension_names
      else
        groups.map { |group| determine_dimension_name(group) }
      end
    end

    def determine_dimension_name(group)
      # split by ., ->>, and -> and remove whitespace
      value = group.to_s.split(/\s*((\.)|(->>)|(->))\s*/).last

      # removing starting and ending quotes
      # for simplicity, they don't need to be the same
      value = value[1..-2] if value.match?(/\A["'`].+["'`]\z/)

      unless value.match?(/\A\w+\z/)
        raise "Cannot determine dimension name: #{group}. Use the dimension_names option"
      end

      value
    end

    # calculation can mutate relation, but that's fine
    def perform_calculation(relation, &block)
      if block_given?
        yield(relation)
      else
        relation.count
      end
    end

    def prepare_result(result, name, dimension_names, interval)
      raise "Expected calculation to return Hash, not #{result.class.name}" unless result.is_a?(Hash)

      time_class = Utils.date_interval?(interval) ? Date : Time
      expected_key_size = dimension_names.size + 1

      result.map do |key, value|
        dimensions = {}
        if dimension_names.any?
          unless key.is_a?(Array) && key.size == expected_key_size
            raise "Expected result key to be Array with size #{expected_key_size}"
          end
          time = key[-1]
          # may be able to support dimensions in SQLite by sorting dimension names
          dimension_names.each_with_index do |dn, i|
            dimensions[dn] = key[i]
          end
        else
          time = key
        end

        raise "Expected time to be #{time_class.name}, not #{time.class.name}" unless time.is_a?(time_class)
        raise "Expected value to be Numeric or nil, not #{value.class.name}" unless value.is_a?(Numeric) || value.nil?

        record = {
          name: name,
          interval: interval,
          time: time,
          value: value
        }
        record[:dimensions] = dimensions
        record
      end
    end

    def maybe_clear(clear, name, interval)
      if clear
        Rollup.transaction do
          Rollup.unscoped.where(name: name, interval: interval).delete_all
          yield
        end
      else
        yield
      end
    end

    def save_records(records)
      # order must match unique index
      # consider using index name instead
      conflict_target = [:name, :interval, :time, :dimensions]
      options = {unique_by: conflict_target}

      utc = ActiveSupport::TimeZone["Etc/UTC"]
      records.each do |v|
        v[:time] = v[:time].in_time_zone(utc) if v[:time].is_a?(Date)
      end

      Rollup.unscoped.upsert_all(records, **options)
    end
  end

  module Utils
    DATE_INTERVALS = %w[day week month quarter year]

    class << self
      def time_sql(interval)
        if date_interval?(interval)
          "date(rollups.time)"
        else
          :time
        end
      end

      def date_interval?(interval)
        DATE_INTERVALS.include?(interval.to_s)
      end
    end
  end
end
