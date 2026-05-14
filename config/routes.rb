Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  resources :books, only: %i[index show create] do
    collection do
      get :search
    end
    member do
      get :similar
    end
  end
end
