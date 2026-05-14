# frozen_string_literal: true

class ReplaceArticlesWithBooks < ActiveRecord::Migration[8.0]
  def up
    execute "DROP INDEX IF EXISTS index_articles_on_embedding_hnsw;"
    drop_table :articles, if_exists: true

    create_table :books do |t|
      t.string :title, null: false
      t.string :url, null: false
      t.text :description, null: false
      t.text :genres
      t.timestamps
    end

    execute <<-SQL.squish
      ALTER TABLE books
      ADD COLUMN embedding vector(1536);
    SQL

    execute <<-SQL.squish
      CREATE INDEX index_books_on_embedding_hnsw
      ON books
      USING hnsw (embedding vector_cosine_ops);
    SQL
  end

  def down
    execute "DROP INDEX IF EXISTS index_books_on_embedding_hnsw;"
    drop_table :books, if_exists: true

    enable_extension "vector" unless extension_enabled?("vector")

    create_table :articles do |t|
      t.string :title, null: false
      t.text :body, null: false
      t.timestamps
    end

    execute <<-SQL.squish
      ALTER TABLE articles
      ADD COLUMN embedding vector(1536);
    SQL

    execute <<-SQL.squish
      CREATE INDEX index_articles_on_embedding_hnsw
      ON articles
      USING hnsw (embedding vector_cosine_ops);
    SQL
  end
end
