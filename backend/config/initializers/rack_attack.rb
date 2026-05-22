# frozen_string_literal: true

return unless Rails.env.production?

Rack::Attack.enabled = true

search_limit = ENV.fetch("RACK_ATTACK_SEARCH_LIMIT", "30").to_i
search_period = ENV.fetch("RACK_ATTACK_SEARCH_PERIOD", "300").to_i
similar_limit = ENV.fetch("RACK_ATTACK_SIMILAR_LIMIT", "60").to_i
similar_period = ENV.fetch("RACK_ATTACK_SIMILAR_PERIOD", "300").to_i
api_limit = ENV.fetch("RACK_ATTACK_API_LIMIT", "120").to_i
api_period = ENV.fetch("RACK_ATTACK_API_PERIOD", "300").to_i

Rack::Attack.safelist("allow-health") do |req|
  req.path == "/up" && req.get?
end

Rack::Attack.throttle("books/search/ip", limit: search_limit, period: search_period) do |req|
  req.ip if req.get? && req.path == "/books/search"
end

Rack::Attack.throttle("books/similar/ip", limit: similar_limit, period: similar_period) do |req|
  req.ip if req.get? && req.path.match?(%r{\A/books/\d+/similar\z})
end

Rack::Attack.throttle("books/api/ip", limit: api_limit, period: api_period) do |req|
  req.ip if req.path.start_with?("/books")
end

Rack::Attack.throttled_responder = lambda do |request|
  match_data = request.env["rack.attack.match_data"]
  now = match_data[:epoch_time]
  retry_after = match_data[:period] - (now % match_data[:period])

  headers = {
    "Content-Type" => "application/json",
    "Retry-After" => retry_after.to_s
  }

  body = { error: "Too many requests. Try again shortly." }.to_json
  [ 429, headers, [ body ] ]
end
