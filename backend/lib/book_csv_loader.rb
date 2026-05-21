# frozen_string_literal: true

require "csv"

module BookCsvLoader
  module_function

  def data_root
    Pathname(ENV.fetch("BOOK_DATA_ROOT", Rails.root.join("..", "data")))
  end

  def processed_dir
    data_root.join("processed")
  end

  def resolve_path
    if ENV["BOOK_SEED_PATH"].present?
      Pathname(ENV["BOOK_SEED_PATH"])
    elsif processed_dir.join("books_top45k.csv").file?
      processed_dir.join("books_top45k.csv")
    elsif processed_dir.join("books_top40k.csv").file?
      processed_dir.join("books_top40k.csv")
    elsif processed_dir.join("book_details.csv").file?
      processed_dir.join("book_details.csv")
    else
      # Legacy fallback if files were not moved yet
      legacy = Rails.root.join("db/book_details.csv")
      legacy.file? ? legacy : processed_dir.join("book_details.csv")
    end
  end

  def load_rows(csv_path, limit: nil)
    raise "Missing CSV: #{csv_path}" unless csv_path.file?

    rows = []
    CSV.foreach(csv_path, headers: true, liberal_parsing: true) do |row|
      title = row["title"]&.strip&.delete("\0")
      url = row["url"]&.strip&.delete("\0")
      description = row["description"]&.strip&.delete("\0")
      genres = row["genres"]&.strip&.delete("\0")
      category = row["category"]&.strip&.delete("\0")

      next if title.blank? || url.blank? || description.blank?

      rows << {
        "title" => title,
        "url" => url,
        "description" => description,
        "genres" => genres.presence,
        "category" => category.presence
      }
      break if limit && rows.size >= limit
    end
    rows
  end
end
