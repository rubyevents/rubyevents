class Announcement
  CONTENT_PATH = Rails.root.join("content", "announcements")

  attr_reader :title, :slug, :date, :author, :published, :excerpt, :tags, :featured_image, :content, :file_path

  def initialize(attributes = {})
    @title = attributes[:title]
    @slug = attributes[:slug]
    @date = attributes[:date]
    @author = attributes[:author]
    @published = attributes[:published] != false
    @excerpt = attributes[:excerpt]
    @tags = attributes[:tags] || []
    @featured_image = attributes[:featured_image]
    @content = attributes[:content]
    @file_path = attributes[:file_path]
  end

  class << self
    def all
      return load_all if Rails.env.local?

      @all ||= load_all
    end

    def published
      all.select(&:published?)
    end

    def by_tag(tag)
      all.select { |a| a.tags.map(&:downcase).include?(tag.downcase) }
    end

    def all_tags
      all.flat_map(&:tags).uniq.sort
    end

    def find_by_slug(slug)
      all.find { |a| a.slug == slug }
    end

    def find_by_slug!(slug)
      find_by_slug(slug) || raise(ActiveRecord::RecordNotFound, "Announcement not found: #{slug}")
    end

    def reload!
      @all = nil
      all
    end

    private

    def load_all
      return [] unless CONTENT_PATH.exist?

      Dir.glob(CONTENT_PATH.join("*.md")).map do |file_path|
        parse_file(file_path)
      end.compact.sort_by(&:date).reverse
    end

    def parse_file(file_path)
      content = File.read(file_path)
      frontmatter, body = extract_frontmatter(content)

      return nil if frontmatter.nil?

      new(
        title: frontmatter["title"],
        slug: frontmatter["slug"] || slug_from_filename(file_path),
        date: parse_date(frontmatter["date"]),
        author: frontmatter["author"],
        published: frontmatter["published"],
        excerpt: frontmatter["excerpt"],
        tags: Array(frontmatter["tags"]),
        featured_image: frontmatter["featured_image"],
        content: body.strip,
        file_path: file_path
      )
    end

    def extract_frontmatter(content)
      return [nil, content] unless content.start_with?("---")

      parts = content.split(/^---\s*$/, 3)
      return [nil, content] if parts.length < 3

      frontmatter = YAML.safe_load(parts[1], permitted_classes: [Date, Time])
      body = parts[2]

      [frontmatter, body]
    end

    def slug_from_filename(file_path)
      filename = File.basename(file_path, ".md")
      filename.sub(/^\d{4}-\d{2}-\d{2}-/, "")
    end

    def parse_date(date)
      case date
      when Date, Time
        date.to_date
      when String
        Date.parse(date)
      else
        Date.today
      end
    end
  end

  def published?
    @published
  end

  def author_user
    return nil if author.blank?

    @author_user ||= User.find_by_github_handle(author)
  end

  def to_param
    slug
  end

  def formatted_date
    date.strftime("%B %d, %Y")
  end
end
