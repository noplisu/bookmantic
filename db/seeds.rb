# frozen_string_literal: true

require "csv"

csv_path = Rails.root.join("db/book_details.csv")
unless csv_path.file?
  raise "Missing seed file: #{csv_path}"
end

# Default: first 200 rows (fast local dev). Set BOOK_SEED_FULL=1 to load every row from the CSV.
# Override row count with BOOK_SEED_LIMIT=500 (ignored when BOOK_SEED_FULL is set).
seed_limit = if ActiveModel::Type::Boolean.new.cast(ENV["BOOK_SEED_FULL"])
  nil
else
  Integer(ENV.fetch("BOOK_SEED_LIMIT", "200"))
end

rows = []
CSV.foreach(csv_path, headers: true, liberal_parsing: true) do |row|
  title = row["title"]&.strip
  url = row["url"]&.strip
  description = row["description"]&.strip
  genres = row["genres"]&.strip

  next if title.blank? || url.blank? || description.blank?

  rows << { title: title, url: url, description: description, genres: genres.presence }
  break if seed_limit && rows.size >= seed_limit
end

puts "Seeding #{rows.size} books from #{csv_path}#{seed_limit ? " (limit #{seed_limit}; set BOOK_SEED_FULL=1 for entire CSV)" : " (full CSV)"}…"

ENV["DISABLE_EMBEDDING_CALLBACKS"] = "1"
rows.each { |attrs| Book.create!(attrs) }
ENV.delete("DISABLE_EMBEDDING_CALLBACKS")

if ENV["OPENAI_API_KEY"].present?
  pending = Book.where("embedding IS NULL").order(:id).to_a
  total = pending.size
  puts "Generating embeddings via OpenAI (#{total} records; this may take a while)…"
  pending.each_with_index do |book, i|
    GenerateEmbeddingJob.perform_now(book.id)
    puts "  #{i + 1}/#{total} (id=#{book.id})" if ((i + 1) % 25).zero? || (i + 1) == total
  end
  with_emb = Book.where("embedding IS NOT NULL").count
  puts "Done. Books with embeddings: #{with_emb} / #{Book.count}."
else
  puts <<~MSG

    OPENAI_API_KEY is not set — embeddings were not generated.
    Set the key, run `bundle exec sidekiq`, then:
      bin/rails runner 'Book.where("embedding IS NULL").find_each { |b| GenerateEmbeddingJob.perform_later(b.id) }'
  MSG
end
