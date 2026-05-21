# frozen_string_literal: true

class BooksController < ApplicationController
  SEARCH_LIMIT = 5

  def index
    books = Book.order(created_at: :desc)
    render json: books.map { |b| book_json(b) }
  end

  def show
    book = Book.find(params[:id])
    render json: book_json(book)
  end

  def create
    book = Book.new(book_params)
    if book.save
      render json: book_json(book), status: :created
    else
      render json: { errors: book.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def search
    q = params[:q].to_s.strip
    if q.blank?
      render json: { error: "Parameter q is required." }, status: :bad_request
      return
    end

    query_vector = EmbeddingService.embed!(q)
    books = Book
      .where.not(embedding: nil)
      .nearest_neighbors(:embedding, query_vector, distance: "cosine")
      .limit(SEARCH_LIMIT)

    render json: books.map { |b| book_json(b, include_distance: true) }
  rescue EmbeddingService::ConfigurationError => e
    render json: { error: e.message }, status: :service_unavailable
  rescue EmbeddingService::Error => e
    render json: { error: e.message }, status: :bad_request
  rescue KeyError => e
    raise e unless e.message.include?("OPENAI_API_KEY")

    render json: { error: "Environment variable OPENAI_API_KEY is not set." }, status: :service_unavailable
  rescue Faraday::Error => e
    Rails.logger.error("[Books#search] #{e.class}: #{e.message}")
    render json: { error: "Could not reach the OpenAI API." }, status: :bad_gateway
  end

  def similar
    book = Book.find(params[:id])
    unless book.embedding.present?
      render json: { error: "Embedding is not available for this book yet." }, status: :unprocessable_entity
      return
    end

    books = Book
      .where.not(id: book.id)
      .where.not(embedding: nil)
      .nearest_neighbors(:embedding, book.embedding, distance: "cosine")
      .limit(SEARCH_LIMIT)

    render json: books.map { |b| book_json(b, include_distance: true) }
  end

  private

  def book_params
    params.require(:book).permit(:title, :url, :description, :genres, :category)
  end

  def book_json(book, include_distance: false)
    h = {
      id: book.id,
      title: book.title,
      url: book.url,
      description: book.description,
      genres: book.genres,
      category: book.category,
      created_at: book.created_at,
      updated_at: book.updated_at,
      embedding_ready: book.embedding.present?
    }
    if include_distance && book.respond_to?(:neighbor_distance) && book.neighbor_distance
      # neighbor_distance is cosine distance; lower values mean closer to the query
      h[:cosine_distance] = book.neighbor_distance.to_f
      h[:cosine_similarity] = (1.0 - book.neighbor_distance.to_f).clamp(-1.0, 1.0)
    end
    h
  end
end
