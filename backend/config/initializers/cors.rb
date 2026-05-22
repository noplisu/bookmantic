# Be sure to restart your server when you modify this file.

# Avoid CORS issues when API is called from the frontend app.
# Handle Cross-Origin Resource Sharing (CORS) in order to accept cross-origin Ajax requests.

# Read more: https://github.com/cyu/rack-cors

cors_methods =
  if Rails.env.production?
    %i[get options head]
  else
    %i[get post put patch delete options head]
  end

Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins ENV.fetch("CORS_ORIGINS", "*").split(",").map(&:strip)

    resource "*",
      headers: :any,
      methods: cors_methods
  end
end
