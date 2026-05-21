# frozen_string_literal: true

require_relative "../book_csv_loader"

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

  desc "Import books from CSV on top of existing rows (skip duplicate URLs). BOOK_SEED_PATH or db/books_top45k.csv"
  task import_csv: :environment do
    unless Book.column_names.include?("category")
      abort "Run `bin/rails db:migrate` first (books.category column is required)."
    end

    csv_path = BookCsvLoader.resolve_path
    limit = if ActiveModel::Type::Boolean.new.cast(ENV["BOOK_SEED_FULL"])
      nil
    elsif ENV["BOOK_SEED_LIMIT"].present?
      Integer(ENV["BOOK_SEED_LIMIT"])
    end

    rows = BookCsvLoader.load_rows(csv_path, limit: limit)
    puts "Loaded #{rows.size} rows from #{csv_path}"

    existing_urls = Book.pluck(:url).to_set
    new_rows = rows.reject { |r| existing_urls.include?(r["url"]) }
    skipped = rows.size - new_rows.size

    puts "Already in database: #{skipped} | to insert: #{new_rows.size}"

    if new_rows.empty?
      puts "Nothing to import."
      next
    end

    update_existing = ActiveModel::Type::Boolean.new.cast(ENV["BOOK_IMPORT_UPDATE"])
    if update_existing
      updated = 0
      rows.each do |r|
        book = Book.find_by(url: r["url"])
        next unless book

        attrs = {}
        attrs[:category] = r["category"] if r["category"].present? && book.category != r["category"]
        attrs[:genres] = r["genres"] if r["genres"].present? && book.genres != r["genres"]
        next if attrs.empty?

        book.update_columns(attrs.merge(updated_at: Time.current))
        updated += 1
      end
      puts "Updated category/genres on #{updated} existing books (BOOK_IMPORT_UPDATE=1)."
    end

    ENV["DISABLE_EMBEDDING_CALLBACKS"] = "1"
    now = Time.current
    batch_size = Integer(ENV.fetch("BOOK_SEED_BATCH_SIZE", "500"))
    new_rows.each_slice(batch_size) do |slice|
      Book.insert_all(
        slice.map { |r| r.merge("created_at" => now, "updated_at" => now) }
      )
    end
    ENV.delete("DISABLE_EMBEDDING_CALLBACKS")

    new_ids = Book.where(url: new_rows.map { |r| r["url"] }).pluck(:id)
    puts "Inserted #{new_ids.size} books."

    if ENV["OPENAI_API_KEY"].present?
      puts "Enqueueing #{new_ids.size} embedding jobs for new books…"
      new_ids.each { |id| GenerateEmbeddingJob.perform_later(id) }
      puts "Done. Ensure Sidekiq is running."
    else
      puts "OPENAI_API_KEY not set — run `bin/rails books:enqueue_embeddings` after setting it."
    end
  end
end
