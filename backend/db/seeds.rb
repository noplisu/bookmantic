# frozen_string_literal: true

require "csv"

def seed_csv_path
  if ENV["BOOK_SEED_PATH"].present?
    Rails.root.join(ENV["BOOK_SEED_PATH"])
  elsif Rails.root.join("db/books_top40k.csv").file?
    Rails.root.join("db/books_top40k.csv")
  else
    Rails.root.join("db/book_details.csv")
  end
end

csv_path = seed_csv_path
unless csv_path.file?
  raise "Missing seed CSV. Generate db/books_top40k.csv (see README) or add db/book_details.csv. " \
        "Override with BOOK_SEED_PATH."
end

# Cap rows for quick dev (full export is ~40k). BOOK_SEED_FULL=1 uses entire file.
seed_limit = if ActiveModel::Type::Boolean.new.cast(ENV["BOOK_SEED_FULL"])
  nil
else
  Integer(ENV.fetch("BOOK_SEED_LIMIT", "200"))
end

rows = []
CSV.foreach(csv_path, headers: true, liberal_parsing: true) do |row|
  title = row["title"]&.strip&.delete("\0")
  url = row["url"]&.strip&.delete("\0")
  description = row["description"]&.strip&.delete("\0")
  genres = row["genres"]&.strip&.delete("\0")

  next if title.blank? || url.blank? || description.blank?

  rows << {
    "title" => title,
    "url" => url,
    "description" => description,
    "genres" => genres.presence
  }
  break if seed_limit && rows.size >= seed_limit
end

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
