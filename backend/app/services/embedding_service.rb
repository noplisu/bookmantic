# frozen_string_literal: true

class EmbeddingService
  MODEL = "text-embedding-3-small"
  DIMENSIONS = 1536

  class Error < StandardError; end
  class ConfigurationError < Error; end

  class << self
    # OpenAI embedding models cap input length; avoid hard failures on huge OL descriptions.
    MAX_EMBED_CHARS = 50_000

    def embed!(text)
      input = text.to_s.strip
      raise Error, "Text to embed is empty." if input.blank?

      input = input[0, MAX_EMBED_CHARS] if input.length > MAX_EMBED_CHARS

      response = client.embeddings(
        parameters: {
          model: MODEL,
          input: input,
          dimensions: DIMENSIONS
        }
      )

      vector = response.dig("data", 0, "embedding")
      raise Error, "No embedding vector in OpenAI response." if vector.blank? || vector.size != DIMENSIONS

      vector
    end

    def client
      @client ||= OpenAI::Client.new(
        access_token: openai_access_token,
        request_timeout: 120
      )
    end

    private

    def openai_access_token
      key = ENV["OPENAI_API_KEY"]&.strip
      if key.blank?
        raise ConfigurationError,
          "OPENAI_API_KEY is missing. In development set it in `.env` (dotenv-rails) " \
          "or export it in the shell before `bundle exec sidekiq`. " \
          "Sidekiq is a separate process—it does not inherit env vars from the terminal where only `rails server` runs."
      end

      key
    end
  end
end
