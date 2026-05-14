# frozen_string_literal: true

SAMPLE_ARTICLES = [
  {
    title: "Form PIT-37: when you file it",
    body: <<~TEXT.squish
      PIT-37 is a common Polish personal income tax form for individuals taxed under the progressive
      scale. You use it when you earn employment, contract, or B2B-style income and you do not run
      a business taxed with a flat-rate scheme or linear tax. The declaration includes reliefs such as
      child or rehabilitation credits and figures from your employer’s PIT-11. The usual electronic
      filing deadline is the end of April following the tax year.
    TEXT
  },
  {
    title: "How a mortgage works",
    body: <<~TEXT.squish
      A mortgage is long-term financing for buying property secured by a lien. The bank checks
      creditworthiness, down payment, and collateral value. Interest may be fixed or variable, tied
      to a benchmark. You repay in annuity or decreasing installments; compare total cost (APR)
      across offers.
    TEXT
  },
  {
    title: "REST vs GraphQL in production APIs",
    body: <<~TEXT.squish
      REST maps cleanly to resources and standard HTTP verbs, which helps caching and integration.
      GraphQL lets clients pick fields in one query but needs guardrails against expensive queries
      and database overload. The right choice depends on API consumers, data model, and versioning.
    TEXT
  },
  {
    title: "HNSW indexes in vector databases",
    body: <<~TEXT.squish
      HNSW is a small-world layered graph structure that approximates nearest-neighbor search in high
      dimensions. With PostgreSQL and pgvector, an HNSW index speeds queries at the cost of memory
      and build time. Pick a metric aligned with your embedding model—for example cosine distance for
      normalized language-model vectors.
    TEXT
  },
  {
    title: "Account security: MFA and password managers",
    body: <<~TEXT.squish
      Multi-factor authentication greatly reduces the impact of phishing and password theft. Use
      unique passwords per service and store them in a password manager with a strong master
      password. Hardware keys such as WebAuthn add another layer where supported.
    TEXT
  },
  {
    title: "Tomato soup with basil",
    body: <<~TEXT.squish
      Sauté onion and garlic, add passata or peeled fresh tomatoes, simmer twenty minutes. Season
      with salt, pepper, and a pinch of sugar to balance acidity. Finish with fresh basil or
      pesto—great with garlic-rubbed toast.
    TEXT
  },
  {
    title: "What depreciation of fixed assets means",
    body: <<~TEXT.squish
      Depreciation spreads the cost of a fixed asset over its useful life. Rates may follow
      accounting law or an individual chart of accounts for larger entities. Tax rules can differ—
      keep book depreciation and tax depreciation separate.
    TEXT
  },
  {
    title: "Monitoring Rails apps in production",
    body: <<~TEXT.squish
      Structured logs, RED/USE metrics, and distributed traces help diagnose latency. Measure SQL
      time, Sidekiq queues, and external APIs. Base alerts on symptoms such as rising 5xx rates,
      not every single anomaly.
    TEXT
  },
  {
    title: "Introduction to text embeddings",
    body: <<~TEXT.squish
      An embedding is a numeric vector representing text meaning in semantic space. Similar content
      yields nearby vectors under a chosen metric such as cosine. They power semantic search,
      clustering, and RAG where a language model cites chunks found by vector similarity.
    TEXT
  },
  {
    title: "Home insulation tax credit: basics",
    body: <<~TEXT.squish
      Taxpayers may deduct part of insulation, window replacement, or heat-pump installation if they
      meet statutory tests. Keep invoices and technical acceptance documents for audits. Limits and
      eligible works change over time—verify the current tax year.
    TEXT
  },
  {
    title: "Docker Compose for local development",
    body: <<~TEXT.squish
      Compose groups app services in one YAML file: databases, cache, queues. Developers run
      `docker compose up -d` and start the app on the host against published container ports. A
      healthcheck helps migrations wait until the database is ready.
    TEXT
  },
  {
    title: "SOLID principles in Ruby",
    body: <<~TEXT.squish
      Single responsibility, open/closed, Liskov substitution, interface segregation, and
      dependency inversion keep code change-friendly. Ruby teams often favor small classes,
      composition over inheritance, and constructor-based dependency injection.
    TEXT
  },
  {
    title: "Consumer rights for online purchases",
    body: <<~TEXT.squish
      In the EU consumers usually have 14 days to withdraw from distance contracts, with exceptions
      such as personalized services. Sellers must show total price and delivery costs before checkout.
      Defective-goods claims are separate from the cooling-off right.
    TEXT
  },
  {
    title: "Reading a chart of accounts in an LLC",
    body: <<~TEXT.squish
      A chart of accounts organizes business events into synthetic and analytic ledgers. Balance
      accounts show assets and financing; income accounts capture revenue and period costs. Analytics
      track customers, projects, or cost centers without bloating synthetic codes.
    TEXT
  },
  {
    title: "Sidekiq as the Active Job backend",
    body: <<~TEXT.squish
      Sidekiq uses Redis for queues and runs jobs with multiple threads. In Rails set
      `config.active_job.queue_adapter = :sidekiq` and run a worker process beside the web server.
      Monitor retries, Redis limits, and job idempotency.
    TEXT
  },
  {
    title: "Hydration during endurance training",
    body: <<~TEXT.squish
      Fluid and electrolyte loss affects focus and performance. Short sessions may need only water;
      long hot efforts benefit from sodium. Sip steadily instead of chugging large volumes to avoid
      stomach discomfort.
    TEXT
  },
  {
    title: "SQL migrations instead of schema.rb for Postgres-specific types",
    body: <<~TEXT.squish
      When ActiveRecord’s default dumper cannot represent your types, switch to
      `config.active_record.schema_format = :sql`. Rails then maintains `db/structure.sql` with the
      exact DDL—including the `vector` type and an HNSW index from pgvector.
    TEXT
  },
  {
    title: "What the health contribution on income is",
    body: <<~TEXT.squish
      The health contribution funds public healthcare. Its base and rate depend on income source—
      employment versus self-employment. Part of the contribution may offset income tax under
      current rules; verify each tax year.
    TEXT
  },
  {
    title: "Contract testing across microservices",
    body: <<~TEXT.squish
      Contracts describe expected API requests and responses. Tools like Pact catch incompatible
      changes before deploy. Alternatives include consumer tests with recordings or OpenAPI schemas
      validated in CI.
    TEXT
  },
  {
    title: "Vector normalization and cosine metrics",
    body: <<~TEXT.squish
      For unit-length vectors, the dot product matches cosine similarity. Some embedding models
      already return normalized vectors; Euclidean and cosine distances then relate by simple
      formulas. An HNSW index with cosine operators matches that metric in the database.
    TEXT
  }
].freeze

puts "Creating #{SAMPLE_ARTICLES.size} sample articles…"
ENV["DISABLE_EMBEDDING_CALLBACKS"] = "1"
SAMPLE_ARTICLES.each do |attrs|
  Article.create!(attrs)
end
ENV.delete("DISABLE_EMBEDDING_CALLBACKS")

if ENV["OPENAI_API_KEY"].present?
  pending = Article.where("embedding IS NULL").order(:id).to_a
  total = pending.size
  puts "Generating embeddings via OpenAI (#{total} records; this may take a few minutes)…"
  pending.each_with_index do |article, i|
    GenerateEmbeddingJob.perform_now(article.id)
    puts "  #{i + 1}/#{total} (id=#{article.id})" if ((i + 1) % 5).zero?
  end
  with_emb = Article.where("embedding IS NOT NULL").count
  puts "Done. Articles with embeddings: #{with_emb} / #{Article.count}."
else
  puts <<~MSG

    OPENAI_API_KEY is not set — embeddings were not generated.
    Set the key, run `bundle exec sidekiq`, then:
      bin/rails runner 'Article.where("embedding IS NULL").find_each { |a| GenerateEmbeddingJob.perform_later(a.id) }'
  MSG
end
