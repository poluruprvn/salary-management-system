Rails.application.routes.draw do
  # Both engines are development-group gems and this file loads in every environment.
  if defined?(Rswag::Ui::Engine)
    mount Rswag::Ui::Engine => "/api-docs"
    mount Rswag::Api::Engine => "/api-docs"
  end

  namespace :api, defaults: { format: :json } do
    namespace :v1 do
      scope :auth, as: :auth do
        post "sign_in", to: "sessions#create"
        post "refresh", to: "sessions#refresh"
        delete "sign_out", to: "sessions#destroy"
      end

      get "me", to: "me#show"
      get "meta", to: "meta#show"

      resources :employees, only: [ :index, :show, :create, :update ] do
        resources :salary_revisions, only: [ :index, :create, :update, :destroy ]
        resources :audits, only: :index
      end

      resources :countries, only: [ :index, :update ]
      resources :departments, only: :index
      resources :levels, only: :index
      resources :titles, only: :index

      namespace :analytics do
        get "run_rate"
        get "distribution"
      end
    end
  end

  # Outside the API namespace, so no bearer token is required. A load balancer has none.
  get "healthz", to: "health#show", defaults: { format: :json }
  get "readyz", to: "health#ready", defaults: { format: :json }
end
