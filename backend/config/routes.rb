Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  if Rails.env.production?
    resources :books, only: [] do
      collection do
        get :search
      end
      member do
        get :similar
      end
    end
  else
    resources :books, only: %i[index show create] do
      collection do
        get :search
      end
      member do
        get :similar
      end
    end
  end
end
