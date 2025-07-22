Rails.application.routes.draw do
  root to: "analyses#new"
  resources :analyses, only: [:index, :new, :create, :show]

  # Pour la vérification de santé de l'app
  get "up" => "rails/health#show", as: :rails_health_check
end
