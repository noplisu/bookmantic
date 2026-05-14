# frozen_string_literal: true

class Book < ApplicationRecord
  has_neighbors :embedding

  validates :title, presence: true
  validates :url, presence: true
  validates :description, presence: true

  after_create_commit :enqueue_embedding_generation,
    unless: -> { ActiveModel::Type::Boolean.new.cast(ENV["DISABLE_EMBEDDING_CALLBACKS"]) }

  private

  def enqueue_embedding_generation
    GenerateEmbeddingJob.perform_later(id)
  end
end
