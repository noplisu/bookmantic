# frozen_string_literal: true

class ArticlesController < ApplicationController
  def index
    articles = Article.order(created_at: :desc)
    render json: articles.map { |a| article_json(a) }
  end

  def show
    article = Article.find(params[:id])
    render json: article_json(article)
  end

  def create
    article = Article.new(article_params)
    if article.save
      render json: article_json(article), status: :created
    else
      render json: { errors: article.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def search
    q = params[:q].to_s.strip
    if q.blank?
      render json: { error: "Parameter q is required." }, status: :bad_request
      return
    end

    query_vector = EmbeddingService.embed!(q)
    articles = Article
      .nearest_neighbors(:embedding, query_vector, distance: "cosine")
      .limit(20)

    render json: articles.map { |a| article_json(a, include_distance: true) }
  rescue EmbeddingService::ConfigurationError => e
    render json: { error: e.message }, status: :service_unavailable
  rescue EmbeddingService::Error => e
    render json: { error: e.message }, status: :bad_request
  rescue KeyError => e
    raise e unless e.message.include?("OPENAI_API_KEY")

    render json: { error: "Environment variable OPENAI_API_KEY is not set." }, status: :service_unavailable
  rescue Faraday::Error => e
    Rails.logger.error("[Articles#search] #{e.class}: #{e.message}")
    render json: { error: "Could not reach the OpenAI API." }, status: :bad_gateway
  end

  private

  def article_params
    params.require(:article).permit(:title, :body)
  end

  def article_json(article, include_distance: false)
    h = {
      id: article.id,
      title: article.title,
      body: article.body,
      created_at: article.created_at,
      updated_at: article.updated_at,
      embedding_ready: article.embedding.present?
    }
    if include_distance && article.respond_to?(:neighbor_distance) && article.neighbor_distance
      # neighbor_distance is cosine distance; lower values mean closer to the query
      h[:cosine_distance] = article.neighbor_distance.to_f
      h[:cosine_similarity] = (1.0 - article.neighbor_distance.to_f).clamp(-1.0, 1.0)
    end
    h
  end
end
