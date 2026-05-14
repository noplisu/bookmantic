Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  get "articles/search", to: "articles#search"
  resources :articles, only: %i[index show create]
end
