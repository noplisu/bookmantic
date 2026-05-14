# frozen_string_literal: true

class GenerateEmbeddingJob < ApplicationJob
  queue_as :default

  discard_on ActiveRecord::RecordNotFound
  discard_on EmbeddingService::ConfigurationError

  def perform(article_id)
    article = Article.find(article_id)
    text = [ article.title, article.body ].join("\n\n")
    vector = EmbeddingService.embed!(text)
    article.update_column(:embedding, vector)
  end
end
