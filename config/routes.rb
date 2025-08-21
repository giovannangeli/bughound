Rails.application.routes.draw do
  devise_for :users
  root 'home#index'  # Homepage
  
  resources :analyses, only: [:index, :new, :create, :show, :destroy] do
    member do
      post 'duplicate'
    end
  end

  get "up" => "rails/health#show", as: :rails_health_check
end