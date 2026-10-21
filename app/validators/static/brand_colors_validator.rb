# frozen_string_literal: true

module Static
  class BrandColorsValidator < ActiveModel::Validator
    FIELD_ASSET_MAP = {
      "banner_background" => "banner.webp",
      "featured_background" => "featured.webp",
      "featured_color" => "featured.webp"
    }.freeze

    def validate(record)
      root = Pathname.new(record.path_root.to_s)
      assets = root.join("app/assets/images/events", *asset_segments(record))
      defaults = root.join("app/assets/images/events", record.path_params[:series_id] || record.path_params[:id], "default")

      FIELD_ASSET_MAP.each do |field, asset|
        exists = assets.join(asset).exist?
        relative = ->(path) { path.relative_path_from(root) }

        if exists && record[field].blank?
          requirement = series?(record) ? "series with a default #{asset} must define its brand colors" : "events with a custom #{asset} must define brand colors"

          record.errors.add(field, "is not defined but '#{relative.call(assets.join(asset))}' exists, #{requirement}")
        elsif !exists && record[field].present?
          message = if series?(record)
            "is defined but '#{relative.call(assets.join(asset))}' does not exist, series without a default #{asset} must not define brand colors"
          elsif defaults.join(asset).exist?
            "is defined but #{asset} comes from the series default '#{relative.call(defaults.join(asset))}', define #{field} in data/#{record.path_params[:series_id]}/series.yml instead"
          else
            "is defined but '#{asset}' exists neither in #{relative.call(assets)} nor in #{relative.call(defaults)}, events falling back to the global default #{asset} must not define brand colors"
          end

          record.errors.add(field, message)
        end
      end
    end

    private

    def series?(record)
      record.is_a?(Static::EventSeries)
    end

    def asset_segments(record)
      series?(record) ? [record.path_params[:id], "default"] : [record.path_params[:series_id], record.path_params[:id]]
    end
  end
end
