# frozen_string_literal: true

require_relative "../lib/book_csv_loader"

csv_path = BookCsvLoader.resolve_path
unless csv_path.file?
  raise "Missing seed CSV. Generate data/processed/books_top45k.csv (see README) or add book_details.csv there. " \
        "Override with BOOK_SEED_PATH."
end

seed_limit = if ActiveModel::Type::Boolean.new.cast(ENV["BOOK_SEED_FULL"])
  nil
else
  Integer(ENV.fetch("BOOK_SEED_LIMIT", "200"))
end

rows = BookCsvLoader.load_rows(csv_path, limit: seed_limit)

puts "Seeding #{rows.size} books from #{csv_path}#{seed_limit ? " (limit #{seed_limit}; BOOK_SEED_FULL=1 for full file)" : " (full file)"}…"

ENV["DISABLE_EMBEDDING_CALLBACKS"] = "1"
now = Time.current
batch_size = Integer(ENV.fetch("BOOK_SEED_BATCH_SIZE", "500"))
rows.each_slice(batch_size) do |slice|
  Book.insert_all(
    slice.map { |r| r.merge("created_at" => now, "updated_at" => now) }
  )
end
ENV.delete("DISABLE_EMBEDDING_CALLBACKS")

if ENV["OPENAI_API_KEY"].present?
  pending_total = Book.where(embedding: nil).count
  puts "Enqueueing #{pending_total} embedding jobs (Sidekiq). Ensure `bundle exec sidekiq` is running."
  enqueued = 0
  Book.where(embedding: nil).in_batches(of: 1_000) do |rel|
    rel.pluck(:id).each do |id|
      GenerateEmbeddingJob.perform_later(id)
      enqueued += 1
    end
    puts "  enqueued #{enqueued} / #{pending_total}…" if (enqueued % 5_000).zero?
  end
  puts "Done. Enqueued #{enqueued} jobs. Poll Sidekiq until `embedding` is populated."
else
  puts <<~MSG

    OPENAI_API_KEY is not set — no embedding jobs were enqueued.
    After setting the key, run: bin/rails books:enqueue_embeddings
    (with Sidekiq running), or:
      bin/rails runner 'Book.where("embedding IS NULL").find_each { |b| GenerateEmbeddingJob.perform_later(b.id) }'
  MSG
end
