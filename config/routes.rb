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
    end
  end

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Defines the root path route ("/")
  # root "posts#index"
end
