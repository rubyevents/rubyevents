require "public_suffix"

speakers = YAML.load_file("#{Rails.root}/data/speakers.yml")
videos_to_ignore = YAML.load_file("#{Rails.root}/data/videos_to_ignore.yml")

# create speakers
speakers.each do |speaker|
  user = User.find_by_github_handle(speaker["github"]) ||
    User.find_by(slug: speaker["slug"]) ||
    User.find_by_name_or_alias(speaker["name"]) ||
    User.new

  user.name = speaker["name"]
  user.twitter = speaker["twitter"] if speaker["twitter"].present?
  user.github_handle = speaker["github"] if speaker["github"].present?
  user.website = speaker["website"] if speaker["website"].present?
  user.bio = speaker["bio"] if speaker["bio"].present?
  user.save!
rescue ActiveRecord::RecordInvalid => e
  puts "Couldn't save: #{speaker["name"]} (#{speaker["github"]}), error: #{e.message}"
end

series_files = Dir.glob("#{Rails.root}/data/*/series.yml")

series_files.each do |series_file_path|
  series = YAML.load_file(series_file_path)
  series_slug = File.basename(File.dirname(series_file_path))
  event_series = EventSeries.find_or_initialize_by(slug: series_slug)
  event_files = Dir.glob("#{Rails.root}/data/#{event_series.slug}/*/event.yml")

  event_series.update!(
    name: series["name"],
    website: series["website"],
    twitter: series["twitter"] || "",
    youtube_channel_name: series["youtube_channel_name"],
    kind: series["kind"],
    frequency: series["frequency"],
    youtube_channel_id: series["youtube_channel_id"],
    slug: series_slug,
    language: series["language"] || ""
  )

  event_series.sync_aliases_from_list(series["aliases"]) if series["aliases"].present?

  event_files.each do |event_file_path|
    event_data = YAML.load_file(event_file_path)
    event_slug = File.basename(File.dirname(event_file_path))
    event = Event.find_or_create_by(slug: event_slug)

    event.update(
      name: event_data["title"],
      date: event_data["date"] || event_data["published_at"],
      date_precision: event_data["date_precision"] || "day",
      series: event_series,
      website: event_data["website"],
      country_code: event.static_metadata.country&.alpha2,
      start_date: event.static_metadata.start_date,
      end_date: event.static_metadata.end_date,
      kind: event.static_metadata.kind
    )

    event.sync_aliases_from_list(event_data["aliases"]) if event_data["aliases"].present?

    puts event.slug unless Rails.env.test?

    cfp_file_path = "#{Rails.root}/data/#{event_series.slug}/#{event.slug}/cfp.yml"

    if File.exist?(cfp_file_path)
      cfps = YAML.load_file(cfp_file_path)

      cfps.each do |cfp_data|
        event.cfps.find_or_create_by(
          link: cfp_data["link"],
          open_date: cfp_data["open_date"]
        ).update(
          name: cfp_data["name"],
          close_date: cfp_data["close_date"]
        )
      end
    end

    if event.videos_file?
      event.videos_file.each do |talk_data|
        if talk_data["title"].blank? || videos_to_ignore.include?(talk_data["video_id"])
          puts "Ignored video: #{talk_data["raw_title"]}"
          next
        end

        talk = Talk.find_or_initialize_by(static_id: talk_data["id"])
        talk.update_from_yml_metadata!(event: event)

        child_talks = talk_data["talks"]

        next unless child_talks

        Array.wrap(child_talks).each do |child_talk_data|
          child_talk = Talk.find_or_initialize_by(static_id: child_talk_data["id"])
          child_talk.parent_talk = talk
          child_talk.update_from_yml_metadata!(event: event)
        end
      rescue ActiveRecord::RecordInvalid => e
        puts "Couldn't save: #{talk_data["title"]} (#{talk_data["id"]}), error: #{e.message}"
      end
    end

    if event.sponsors_file.exist?
      event.sponsors_file.file.each do |sponsors|
        sponsors["tiers"].each do |tier|
          tier["sponsors"].each do |sponsor|
            s = nil
            domain = nil

            if sponsor["website"].present?
              begin
                uri = URI.parse(sponsor["website"])
                host = uri.host || sponsor["website"]
                parsed = PublicSuffix.parse(host)
                domain = parsed.domain

                s = Organization.find_by(domain: domain) if domain.present?
              rescue PublicSuffix::Error, URI::InvalidURIError
                # If parsing fails, continue with other matching methods
              end
            end

            s ||= Organization.find_by(name: sponsor["name"]) || Organization.find_by(slug: sponsor["slug"]&.downcase)
            s ||= Organization.find_or_initialize_by(name: sponsor["name"])

            s.update(
              website: sponsor["website"],
              description: sponsor["description"],
              domain: domain
              # s.level = sponsor["level"]
              # s.event = event
              # s.organisation = organisation
            )

            s.add_logo_url(sponsor["logo_url"]) if sponsor["logo_url"].present?
            s.logo_url = sponsor["logo_url"] if sponsor["logo_url"].present? && s.logo_url.blank?

            if !s.persisted?
              s = Organization.find_by(slug: s.slug) || Organization.find_by(name: s.name)
            end

            s.save!

            event.sponsors.find_or_create_by!(organization: s, event: event).update!(tier: tier["name"], badge: sponsor["badge"])
          end
        end
      end
    end
  end
end

topics = [
  "A/B Testing",
  "Accessibility (a11y)",
  "ActionCable",
  "ActionMailbox",
  "ActionMailer",
  "ActionPack",
  "ActionText",
  "ActionView",
  "ActiveJob",
  "ActiveModel",
  "ActiveRecord",
  "ActiveStorage",
  "ActiveSupport",
  "Algorithms",
  "Android",
  "Angular.js",
  "Arel",
  "Artificial Intelligence (AI)",
  "Assembly",
  "Authentication",
  "Authorization",
  "Automation",
  "Awards",
  "Background jobs",
  "Behavior-Driven Development (BDD)",
  "Blogging",
  "Bootstrapping",
  "Bundler",
  "Business Logic",
  "Business",
  "Caching",
  "Capybara",
  "Career Development",
  "CI/CD",
  "Client-Side Rendering",
  "Code Golfing",
  "Code Organization",
  "Code Quality",
  "Command Line Interface (CLI)",
  "Communication",
  "Communication",
  "Community",
  "Compiling",
  "Components",
  "Computer Vision",
  "Concurrency",
  "Containers",
  "Content Management System (CMS)",
  "Content Management",
  "Continuous Integration (CI)",
  "Contributing",
  "CRuby",
  "Crystal",
  "CSS",
  "Data Analysis",
  "Data Integrity",
  "Data Migrations",
  "Data Persistence",
  "Data Processing",
  "Database Sharding",
  "Databases",
  "Debugging",
  "Dependency Management",
  "Deployment",
  "Design Patterns",
  "Developer Expierience (DX)",
  "Developer Tooling",
  "Developer Tools",
  "Developer Workflows",
  "DevOps",
  "Distributed Systems",
  "Diversity & Inclusion",
  "Docker",
  "Documentation Tools",
  "Documentation",
  "Domain Driven Design",
  "Domain Specific Language (DSL)",
  "dry-rb",
  "Duck Typing",
  "E-Commerce",
  "Early-Career Devlopers",
  "Editor",
  "Elm",
  "Encoding",
  "Encryption",
  "Engineering Culture",
  "Error Handling",
  "Ethics",
  "Event Sourcing",
  "Fibers",
  "Flaky Tests",
  "Frontend",
  "Functional Programming",
  "Game Shows",
  "Games",
  "Geocoding",
  "git",
  "Go",
  "Graphics",
  "GraphQL",
  "gRPC",
  "Hacking",
  "Hanami",
  "Hotwire",
  "HTML",
  "HTTP API",
  "Hybrid Apps",
  "Indie Developer",
  "Inspiration",
  "Integrated Development Environment (IDE)",
  "Integration Test",
  "Internals",
  "Internationalization (I18n)",
  "Interview",
  "iOS",
  "Java Virtual Machine (JVM)",
  "JavaScript",
  "Job Interviewing",
  "JRuby",
  "JSON Web Tokens (JWT)",
  "Just-In-Time (JIT)",
  "Kafka",
  "Keynote",
  "Language Server Protocol (LSP)",
  "Large Language Models (LLM)",
  "Leadership",
  "Legacy Applications",
  "Licensing",
  "Lightning Talks",
  "Linters",
  "Live Coding",
  "Localization (L10N)",
  "Logging",
  "Machine Learning",
  "Majestic Monolith",
  "Markup",
  "Math",
  "Memory Managment",
  "Mental Health",
  "Mentorship",
  "MFA/2FA",
  "Microcontroller",
  "Microservices",
  "Minimum Viable Product (MVP)",
  "Minitest",
  "MJIT",
  "Mocking",
  "Model-View-Controller (MVC)",
  "Monitoring",
  "Monolith",
  "mruby",
  "Multitenancy",
  "Music",
  "MySQL",
  "Naming",
  "Native Apps",
  "Native Extensions",
  "Networking",
  "Object-Oriented Programming (OOP)",
  "Object-Relational Mapper (ORM)",
  "Observability",
  "Offline-First",
  "Open Source",
  "Organizational Skills",
  "Pair Programming",
  "Panel Discussion",
  "Parallelism",
  "Parsing",
  "Passwords",
  "People Skills",
  "Performance",
  "Personal Development",
  "Phlex",
  "Podcasts",
  "PostgreSQL",
  "Pricing",
  "Privacy",
  "Productivity",
  "Profiling",
  "Progressive Web Apps (PWA)",
  "Project Planning",
  "Quality Assurance (QA)",
  "Questions and Anwsers (Q&A)",
  "Rack",
  "Ractors",
  "Rails at Scale",
  "Rails Engine",
  "Rails Plugins",
  "Rails Upgrades",
  "Railties",
  "React.js",
  "Real-Time Applications",
  "Refactoring",
  "Regex",
  "Remote Work",
  "Reporting",
  "REST API",
  "REST",
  "Rich Text Editor",
  "RJIT",
  "Robot",
  "RPC",
  "RSpec",
  "Ruby Implementations",
  "Ruby on Rails",
  "Ruby VM",
  "Rubygems",
  "Rust",
  "Scaling",
  "Science",
  "Security Vulnerability",
  "Security",
  "Selenium",
  "Server-side Rendering",
  "Servers",
  "Service Objects",
  "Shoes.rb",
  "Sidekiq",
  "Sinatra",
  "Single Page Applications (SPA)",
  "Software Architecture",
  "Sonic Pi",
  "Sorbet",
  "SQLite",
  "Startups",
  "Static Typing",
  "Stimulus.js",
  "Structured Query Language (SQL)",
  "Success Stories",
  "Swift",
  "Syntax",
  "System Programming",
  "System Test",
  "Tailwind CSS",
  "Teaching",
  "Team Building",
  "Teams",
  "Teamwork",
  "Templating",
  "Template Engine",
  "Test Coverage",
  "Test Framework",
  "Test-Driven Development",
  "Testing",
  "Threads",
  "Timezones",
  "Tips & Tricks",
  "Trailblazer",
  "Translation",
  "Transpilation",
  "TruffleRuby",
  "Turbo Native",
  "Turbo",
  "Type Checking",
  "Types",
  "Typing",
  "UI Design",
  "Unit Test",
  "Usability",
  "User Interface (UI)",
  "Version Control",
  "ViewComponent",
  "Views",
  "Virtual Machine",
  "Vue.js",
  "Web Components",
  "Web Server",
  "Websockets",
  "why the lucky stiff",
  "Workshop",
  "Writing",
  "YARV (Yet Another Ruby VM)",
  "YJIT (Yet Another Ruby JIT)"
]

# create topics
Topic.create_from_list(topics, status: :approved)

User.order(Arel.sql("RANDOM()")).limit(5).each do |user|
  user.watched_talk_seeder.seed_development_data
end
Rake::Task["backfill:speaker_participation"].invoke
Rake::Task["backfill:event_involvements"].invoke
Rake::Task["speakerdeck:set_usernames_from_slides_url"].invoke
begin
  Rake::Task["contributors:fetch"].invoke
rescue ApplicationClient::Unauthorized => e
  puts "Skipping fetching contributors: #{e.message}"
end
