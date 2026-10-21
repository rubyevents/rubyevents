# frozen_string_literal: true

module Static
  class SponsorSlugValidator < ActiveModel::EachValidator
    def validate_each(sponsor, attribute, slug)
      expected = expected_slug(sponsor)
      return unless expected

      sponsor.errors.add(attribute, %("#{slug}" does not match the parameterized name "#{expected}" for sponsor "#{sponsor["name"]}". Run `bin/rails validate:fix` to update it.), at: sponsor.key?("slug") ? "slug" : "name")
    end

    def fix(sponsor)
      expected = expected_slug(sponsor)
      return 0 unless expected

      sponsor["slug"] = expected

      1
    end

    private

    def expected_slug(sponsor)
      name = sponsor["name"].to_s
      expected = name.parameterize

      expected unless name.blank? || expected.blank? || sponsor["slug"].to_s == expected
    end
  end
end
