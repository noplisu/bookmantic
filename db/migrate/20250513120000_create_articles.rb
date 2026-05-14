class CreateArticles < ActiveRecord::Migration[8.0]
  def up
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

  def down
    execute "DROP INDEX IF EXISTS index_articles_on_embedding_hnsw;"
    drop_table :articles, if_exists: true
  end
end
