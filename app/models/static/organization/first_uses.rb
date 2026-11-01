# frozen_string_literal: true

require "open3"

module Static
  class Organization
    # Organizations a series references for the first time: a sponsors.yml or involvements.yml in the series' folder
    # names an organization that was already in data/organizations.yml before, but no file of that series named it.
    # Giving a different organization an existing slug merges the two by accident, so a human checks each of them.
    # Organizations the change adds are new, not reused, and aren't listed.
    class FirstUses
      FILES = %w[sponsors.yml involvements.yml].freeze
      MARKER = "<!-- new-references-summary -->"
      OTHER_SERIES_SHOWN = 3

      Reference = Data.define(:series, :slug, :path, :line)

      # One per series and organization. The organization (names, websites) and the other series come from the base,
      # which is what the reviewer compares against, so the report never repeats text from the change.
      Finding = Data.define(:series, :organization, :references, :other_series)

      # The data/ folder of two git refs, compared on the sponsors.yml and involvements.yml files that differ.
      # Without `head`, the working tree is compared, uncommitted changes included.
      def self.between(base:, head: nil)
        Dir.mktmpdir("first_uses") do |dir|
          base_commit = git("merge-base", base, head || "HEAD").strip
          base_root = export(base_commit, File.join(dir, "base"))
          head_root = head ? export(head, File.join(dir, "head")) : Rails.root.to_s

          paths = git("diff", "--name-only", "-z", "--diff-filter=d", base_commit, *head, "--", "data").split("\0")
          paths += git("ls-files", "--others", "--exclude-standard", "-z", "--", "data").split("\0") unless head
          paths = paths.select { |path| File.basename(path).in?(FILES) }

          # An export-ignore in a .gitattributes would leave a file out of the export, and so out of the check
          hidden = paths.reject { |path| File.exist?(File.join(head_root, path)) }
          raise "#{hidden.join(", ")} missing from the export of #{head}" if hidden.any?

          yield new(base_root: base_root, head_root: head_root, paths: paths)
        end
      end

      def self.git(*arguments)
        output, status = Open3.capture2("git", "-c", "core.quotePath=false", *arguments, chdir: Rails.root.to_s)
        raise "git #{arguments.join(" ")} failed" unless status.success?

        output
      end

      def self.export(ref, root)
        FileUtils.mkdir_p(root)
        statuses = Open3.pipeline(["git", "archive", "--format=tar", ref, "data"], ["tar", "-x", "-C", root], chdir: Rails.root.to_s)
        raise "Could not export data/ of #{ref}" unless statuses.all?(&:success?)

        root
      end

      # `paths` (relative to head_root) limits the head side to these files, nil means all of them
      def initialize(base_root:, head_root:, paths: nil)
        @base_root = base_root.to_s
        @head_root = head_root.to_s
        @paths = paths
      end

      def findings
        @findings ||= begin
          base_organizations = organizations(@base_root)
          base_uses = Hash.new { |hash, slug| hash[slug] = Set.new }
          references(@base_root).each do |reference|
            organization = base_organizations[reference.slug]
            base_uses[organization.slug] << reference.series if organization
          end

          new_references = references(@head_root, @paths).select do |reference|
            organization = base_organizations[reference.slug]
            organization && !base_uses[organization.slug].include?(reference.series)
          end

          new_references.group_by { |reference| [reference.series, base_organizations[reference.slug].slug] }.sort.map do |(series, slug), references|
            Finding.new(series: series, organization: base_organizations[slug], references: references.sort_by { |reference| [reference.path, reference.line] }, other_series: base_uses[slug].sort)
          end
        end
      end

      # The pull request comment in Markdown, or nil without findings. `link` turns a path and line into a URL.
      def report(link: nil)
        return if findings.empty?

        sections = findings.group_by(&:series).map do |series, series_findings|
          <<~MARKDOWN
            <details>
            <summary><h2>By <code>#{series}</code></h2></summary>

            ### New organization references

            #{series_findings.map { |finding| organization_section(finding, link) }.join("\n\n")}

            </details>
          MARKDOWN
        end

        <<~MARKDOWN
          # New references detected

          Some event series refer to global data for the first time. Please review these references to prevent accidental data merges!

          #{sections.join("\n")}
          #{MARKER}
        MARKDOWN
      end

      private

      def organization_section(finding, link)
        organization = finding.organization
        others = finding.other_series

        lines = [
          "`#{organization.slug}`:",
          "- Names: #{organization.all_names.join(", ")}",
          "- Websites: #{organization.all_websites.join(", ").presence || "none"}",
          "- New references:"
        ]
        lines += finding.references.map do |reference|
          text = "#{reference.path.delete_prefix("#{finding.series}/")}:#{reference.line}"
          url = link&.call(reference.path, reference.line)
          "  - #{url ? "[#{text}](#{url})" : "`#{text}`"}"
        end

        if others.empty?
          lines << "- Not referenced by any other series yet"
        else
          lines << "- Also referenced by #{others.size} other series#{(others.size > OTHER_SERIES_SHOWN) ? ", e.g." : ":"}"
          lines += others.first(OTHER_SERIES_SHOWN).map { |series| "  - `#{series}`" }
        end

        lines.join("\n")
      end

      # slug or alias slug => the organization
      def organizations(root)
        path = File.join(root, "data/organizations.yml")
        return {} if !File.file?(path) || File.symlink?(path)

        Static::Organization.in_file(path).each_with_object({}) do |organization, index|
          [organization.slug, *organization.alias_slugs].each { |slug| index[slug] = organization }
        end
      end

      def references(root, paths = nil)
        files = paths ? paths.map { |path| File.join(root, path) } : Dir.glob(File.join(root, "data/**/{sponsors,involvements}.yml"))

        files.select { |file| File.file?(file) && !File.symlink?(file) }.flat_map do |file|
          series = series_of(root, file)
          path = file.delete_prefix("#{root}/")

          Static::Organization.listings_in(file).map { |listing| Reference.new(series: series, slug: listing.slug, path: path, line: listing.line) }
        end
      end

      # A series' own file sits next to its series.yml; an event's file sits in a folder below it
      def series_of(root, file)
        folder = File.dirname(file)
        folder = File.dirname(folder) unless File.exist?(File.join(folder, "series.yml"))

        folder.delete_prefix("#{root}/")
      end
    end
  end
end
