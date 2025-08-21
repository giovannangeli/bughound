Rails.application.routes.draw do
  devise_for :users
  root 'home#index'  # Homepage
  
resources :analyses, only: [:index, :new, :create, :show, :destroy] do
  member do
    get 'share'
    get 'download_pdf'
  end
end

  get "up" => "rails/health#show", as: :rails_health_check
end