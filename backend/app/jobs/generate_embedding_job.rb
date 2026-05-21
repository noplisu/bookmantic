# frozen_string_literal: true

class GenerateEmbeddingJob < ApplicationJob
  queue_as :default

  discard_on ActiveRecord::RecordNotFound
  discard_on EmbeddingService::ConfigurationError

  def perform(book_id)
    book = Book.find(book_id)
    parts = [ book.title, book.description ]
    parts << "Category: #{book.category}" if book.category.present?
    parts << book.genres if book.genres.present?
    text = parts.join("\n\n")
    vector = EmbeddingService.embed!(text)
    book.update_column(:embedding, vector)
  end
end
