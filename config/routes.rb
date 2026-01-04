# == Route Map
#

Rails.application.routes.draw do
  extend Authenticator

  # static pages
  get "/uses", to: "page#uses"
  get "/privacy", to: "page#privacy"
  get "/components", to: "page#components"
  get "/about", to: "page#about"
  get "/stickers", to: "page#stickers"
  get "/contributors", to: "page#contributors"
  get "/stamps", to: "stamps#index"
  get "/wrapped", to: "wrapped#index"
  get "/pages/assets", to: "page#assets"
  get "/featured" => "page#featured"

  # authentication
  get "/auth/failure", to: "sessions/omniauth#failure"
  get "/auth/:provider/callback", to: "sessions/omniauth#create"
  post "/auth/:provider/callback", to: "sessions/omniauth#create"
  resources :sessions, only: [:new, :create, :destroy]

  resource :password, only: [:edit, :update]
  resource :settings, only: [:show, :update]
  namespace :identity do
    resource :email, only: [:edit, :update]
    resource :email_verification, only: [:show, :create]
    resource :password_reset, only: [:new, :edit, :create, :update]
  end

  authenticate :admin do
    mount MissionControl::Jobs::Engine, at: "/jobs"
    mount Avo::Engine, at: Avo.configuration.root_path
  end

  resources :topics, param: :slug, only: [:index, :show]
  resources :cfp, only: :index
  resources :countries, param: :slug, only: [:index, :show]

  get "/states", to: "states#index", as: :states
  get "/states/:alpha2", to: "states#country_index", as: :country_states
  get "/states/:alpha2/:slug", to: "states#show", as: :state

  get "/cities", to: "cities#index", as: :cities
  get "/cities/:alpha2/:state/:city", to: "cities#show_with_state", as: :city_with_state, constraints: {alpha2: /[a-z]{2}/i}
  get "/cities/:alpha2/:city", to: "cities#show_by_country", as: :city_by_country, constraints: {alpha2: /[a-z]{2}/i}
  get "/cities/:slug", to: "cities#show", as: :city

  resources :featured_cities, only: [:create, :destroy], param: :slug

  resources :gems, param: :gem_name, only: [:index, :show] do
    member do
      get :talks
    end
  end

  namespace :profiles do
    resources :connect, only: [:index, :show]
    resources :claims, only: [:create]
    resources :enhance, only: [:update], param: :slug
  end

  resources :contributions, only: [:index, :show], param: :step

  resources :templates, only: [:new, :create] do
    collection do
      get :new_child
      delete :delete_child
      get :speakers_search
      post :speakers_search_chips
    end
  end

  # resources
  namespace :analytics do
    resource :dashboards, only: [:show] do
      get :daily_page_views
      get :daily_visits
      get :monthly_page_views
      get :monthly_visits
      get :top_referrers
      get :top_landing_pages
      get :yearly_conferences
      get :yearly_talks
      get :top_searches
    end
  end

  resources :talks, param: :slug, only: [:index, :show, :update, :edit] do
    scope module: :talks do
      resources :recommendations, only: [:index]
      resource :watched_talk, only: [:new, :create, :destroy, :update] do
        post :toggle_attendance, on: :collection
        post :toggle_online, on: :collection
      end
      resource :slides, only: :show
    end
  end

  resources :watched_talks, only: [:index, :destroy]

  resources :speakers, param: :slug, only: [:index]
  get "/speakers/:slug", to: redirect("/profiles/%{slug}", status: 301), as: :speaker

  resources :profiles, param: :slug, only: [:show, :update, :edit] do
    scope module: :profiles do
      resources :talks, only: [:index]
      resources :events, only: [:index]
      resources :mutual_events, only: [:index]
      resources :stamps, only: [:index]
      resources :stickers, only: [:index]
      resources :involvements, only: [:index]
      resources :map, only: [:index]
      resources :aliases, only: [:index]
      resources :wrapped, only: [:index] do
        collection do
          get :card
          get :og_image
          post :toggle_visibility
          post :generate_card
        end
      end
    end
  end

  resources :favorite_users, only: [:index, :create, :destroy]

  resources :events, param: :slug, only: [:index, :show, :update, :edit] do
    resources :event_participations, only: [:create, :destroy]

    scope module: :events do
      collection do
        get "/:year" => "years#index", :as => :year, :constraints => {year: /\d{4}/}
        get "/past" => "past#index", :as => :past
        get "/archive" => "archive#index", :as => :archive
        get "/countries" => redirect("/countries")
        get "/countries/:country" => redirect { |params, _| "/countries/#{params[:country]}" }
        get "/cities", to: redirect("/cities", status: 301)
        get "/cities/:city", to: redirect("/cities", status: 301)
        resources :series, param: :slug, only: [:index, :show]
        resources :attendances, only: [:index, :show], param: :event_slug
      end

      resources :schedules, only: [:index], path: "/schedule" do
        get "/day/:date", action: :show, on: :collection, as: :day
      end
      resource :venue, only: [:show]
      resources :speakers, only: [:index]
      resources :participants, only: [:index]
      resources :involvements, only: [:index]
      resources :talks, only: [:index]
      resources :related_talks, only: [:index]
      resources :events, only: [:index, :show]
      resources :videos, only: [:index]
      resources :sponsors, only: [:index]
      resources :cfp, only: [:index]
      resources :collectibles, only: [:index]
    end
  end

  resources :organizations, param: :slug, only: [:index, :show] do
    resource :logos, only: [:show, :update], controller: "organizations/logos"
    resources :wrapped, only: [:index], controller: "organizations/wrapped" do
      collection do
        get :og_image
      end
    end
  end

  namespace :sponsors do
    resources :missing, only: [:index]
  end

  get "/sponsors", to: redirect("/organizations", status: 301)
  get "/sponsors/:slug", to: redirect("/organizations/%{slug}", status: 301)
  get "/sponsors/:slug/logos", to: redirect("/organizations/%{slug}/logos", status: 301)

  get "/organisations", to: redirect("/events/series")
  get "/organisations/:slug", to: redirect("/events/series/%{slug}")

  namespace "spotlight" do
    resources :talks, only: [:index]
    resources :speakers, only: [:index]
    resources :events, only: [:index]
    resources :topics, only: [:index]
    resources :series, only: [:index]
    resources :organizations, only: [:index]
    resources :locations, only: [:index]
    resources :languages, only: [:index]
  end

  resources :recommendations, only: [:index]

  get "leaderboard", to: "leaderboard#index"

  # admin
  namespace :admin, if: -> { Current.user & admin? } do
    resources :suggestions, only: %i[index update destroy]
  end

  get "/sitemap.xml", to: "sitemaps#show", defaults: {format: "xml"}

  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", :as => :rails_health_check

  # Defines the root path route ("/")
  root "page#home"

  resources :watch_lists, only: [:index, :new, :create, :show, :edit, :update, :destroy], path: "bookmarks" do
    resources :talks, only: [:create, :destroy], controller: "watch_list_talks"
  end

  namespace :hotwire do
    namespace :native do
      namespace :v1 do
        get "home", to: "/page#home", defaults: {format: "json"}
        namespace :android do
          resource :path_configuration, only: :show
        end
        namespace :ios do
          resource :path_configuration, only: :show
        end
      end
    end
  end
end
