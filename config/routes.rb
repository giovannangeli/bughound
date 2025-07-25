Rails.application.routes.draw do
  root 'home#index'  # Homepage
  resources :analyses, only: [:index, :new, :create, :show]

  get "up" => "rails/health#show", as: :rails_health_check
end
