# frozen_string_literal: true

class AmazonLinkBuilder
  class << self
    def search_url_for(title:)
      tag = associate_tag
      return nil if tag.blank?

      host = marketplace_host
      query = CGI.escape(title.to_s.strip)
      "https://#{host}/s?k=#{query}&tag=#{tag}"
    end

    private

    def associate_tag
      ENV["AMAZON_ASSOCIATE_TAG"]&.strip.presence
    end

    def marketplace_host
      ENV.fetch("AMAZON_MARKETPLACE_HOST", "www.amazon.com").strip.sub(%r{\Ahttps?://}, "")
    end
  end
end
