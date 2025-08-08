require "public_suffix"

speakers = YAML.load_file("#{Rails.root}/data/speakers.yml")
organisations = YAML.load_file("#{Rails.root}/data/organisations.yml")
videos_to_ignore = YAML.load_file("#{Rails.root}/data/videos_to_ignore.yml")

# create speakers
speakers.each do |speaker|
  Speaker.find_or_create_by!(slug: speaker["slug"]) do |s|
    s.name = speaker["name"]
    s.twitter = speaker["twitter"]
    s.github = speaker["github"]
    s.website = speaker["website"]
    s.bio = speaker["bio"]
  end
end

MeiliSearch::Rails.deactivate! do
  organisations.each do |org|
    organisation = Organisation.find_or_initialize_by(slug: org["slug"])

    organisation.update!(
      name: org["name"],
      website: org["website"],
      twitter: org["twitter"] || "",
      youtube_channel_name: org["youtube_channel_name"],
      kind: org["kind"],
      frequency: org["frequency"],
      youtube_channel_id: org["youtube_channel_id"],
      slug: org["slug"],
      language: org["language"] || ""
    )

    events = YAML.load_file("#{Rails.root}/data/#{organisation.slug}/playlists.yml")

    events.each do |event_data|
      event = Event.find_or_create_by(slug: event_data["slug"])

      event.update(
        name: event_data["title"],
        date: event_data["date"] || event_data["published_at"],
        date_precision: event_data["date_precision"] || "day",
        organisation: organisation,
        website: event_data["website"],
        start_date: event.static_metadata.start_date,
        end_date: event.static_metadata.end_date,
        kind: event.static_metadata.kind,
        cfp_close_date: event_data["cfp_close_date"],
        cfp_link: event_data["cfp_link"],
        cfp_open_date: event_data["cfp_open_date"]
      )

      puts event.slug unless Rails.env.test?

      talks = YAML.load_file("#{Rails.root}/data/#{organisation.slug}/#{event.slug}/videos.yml")

      talks.each do |talk_data|
        if talk_data["title"].blank? || videos_to_ignore.include?(talk_data["video_id"])
          puts "Ignored video: #{talk_data["raw_title"]}"
          next
        end

        talk = Talk.find_by(video_id: talk_data["video_id"], video_provider: talk_data["video_provider"])
        talk = Talk.find_by(video_id: talk_data["video_id"]) if talk.blank?
        talk = Talk.find_by(video_id: talk_data["id"].to_s) if talk.blank?
        talk = Talk.find_by(slug: talk_data["slug"].to_s) if talk.blank?

        talk = Talk.find_or_initialize_by(video_id: talk_data["video_id"].to_s) if talk.blank?

        talk.video_provider = talk_data["video_provider"] || :youtube
        talk.update_from_yml_metadata!(event: event)

        child_talks = Array.wrap(talk_data["talks"])

        next if child_talks.none?

        child_talks.each do |child_talk_data|
          child_talk = Talk.find_by(video_id: child_talk_data["video_id"], video_provider: child_talk_data["video_provider"])
          child_talk = Talk.find_by(video_id: child_talk_data["video_id"]) if child_talk.blank?
          child_talk = Talk.find_by(video_id: child_talk_data["id"].to_s) if child_talk.blank?
          child_talk = Talk.find_by(slug: child_talk_data["slug"].to_s) if child_talk.blank?

          child_talk = Talk.find_or_initialize_by(video_id: child_talk_data["video_id"].to_s) if child_talk.blank?

          child_talk.video_provider = child_talk_data["video_provider"] || :parent
          child_talk.parent_talk = talk
          child_talk.update_from_yml_metadata!(event: event)
        end
      rescue ActiveRecord::RecordInvalid => e
        puts "Couldn't save: #{talk_data["title"]} (#{talk_data["video_id"]}), error: #{e.message}"
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

                  s = Sponsor.find_by(domain: domain) if domain.present?
                rescue PublicSuffix::Error, URI::InvalidURIError
                  # If parsing fails, continue with other matching methods
                end
              end

              s ||= Sponsor.find_by(name: sponsor["name"]) || Sponsor.find_by(slug: sponsor["slug"]&.downcase)
              s ||= Sponsor.find_or_initialize_by(name: sponsor["name"])

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
                s = Sponsor.find_by(slug: s.slug) || Sponsor.find_by(name: s.name)
              end

              s.save!

              event.event_sponsors.find_or_create_by!(sponsor: s, event: event).update!(tier: tier["name"])
            end
          end
        end
      end
    end
  end
end

# reindex all talk in MeiliSearch
# Talk.reindex! unless Rails.env.test? || Rails.env.production?

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
