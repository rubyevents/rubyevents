# == Route Map
#

Rails.application.routes.draw do
  extend Authenticator

  # static pages
  get "uses", to: "page#uses"
  get "/privacy", to: "page#privacy"
  get "/components", to: "page#components"
  get "/about", to: "page#about"
  get "/stickers", to: "page#stickers"

  # authentication
  get "/auth/failure", to: "sessions/omniauth#failure"
  get "/auth/:provider/callback", to: "sessions/omniauth#create"
  post "/auth/:provider/callback", to: "sessions/omniauth#create"
  get "sign_in", to: "sessions#new"
  post "sign_in", to: "sessions#create"
  get "sign_up", to: "registrations#new"
  post "sign_up", to: "registrations#create"

  authenticate :admin do
    mount MissionControl::Jobs::Engine, at: "/jobs"
    mount Avo::Engine, at: Avo.configuration.root_path
  end

  resources :topics, param: :slug, only: [:index, :show]
  resources :sessions, only: [:index, :show, :destroy]
  resource :password, only: [:edit, :update]
  namespace :identity do
    resource :email, only: [:edit, :update]
    resource :email_verification, only: [:show, :create]
    resource :password_reset, only: [:new, :edit, :create, :update]
  end

  resources :contributions, only: [:index, :show], param: :step

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
      resource :watched_talk, only: [:create, :destroy]
      resource :slides, only: :show
    end
  end

  resources :speakers, param: :slug, only: [:index, :show, :update, :edit]
  resources :events, param: :slug, only: [:index, :show, :update, :edit] do
    scope module: :events do
      collection do
        get "/past" => "past#index", :as => :past
        get "/archive" => "archive#index", :as => :archive
        resources :countries, param: :country, only: [:index, :show]
      end

      resources :schedules, only: [:index], path: "/schedule" do
        get "/day/:date", action: :show, on: :collection, as: :day
      end
      resources :speakers, only: [:index]
      resources :talks, only: [:index]
      resources :related_talks, only: [:index]
      resources :events, only: [:index]
      resources :videos, only: [:index]
    end
  end
  resources :organisations, param: :slug, only: [:index, :show]

  namespace :speakers do
    resources :enhance, only: [:update], param: :slug
  end

  namespace "spotlight" do
    resources :talks, only: [:index]
    resources :speakers, only: [:index]
    resources :events, only: [:index]
  end

  get "/featured" => "page#featured"

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

  resources :watch_lists, only: [:index, :new, :create, :show, :edit, :update, :destroy] do
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
