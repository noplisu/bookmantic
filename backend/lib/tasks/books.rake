# frozen_string_literal: true

namespace :books do
  desc "Enqueue GenerateEmbeddingJob for every book with a NULL embedding (requires Sidekiq + OPENAI_API_KEY)"
  task enqueue_embeddings: :environment do
    pending = Book.where(embedding: nil)
    total = pending.count
    if total.zero?
      puts "No books with NULL embedding."
    else
      puts "Enqueueing #{total} embedding jobs…"
      enqueued = 0
      pending.in_batches(of: 1_000) do |rel|
        rel.pluck(:id).each do |id|
          GenerateEmbeddingJob.perform_later(id)
          enqueued += 1
        end
        puts "  #{enqueued} / #{total}" if (enqueued % 5_000).zero?
      end
      puts "Enqueued #{enqueued} jobs. Start Sidekiq if needed: bundle exec sidekiq"
    end
  end
end
