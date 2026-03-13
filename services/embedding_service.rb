# frozen_string_literal: true

require_relative '../models/embedding'
require_relative '../models/search_result'
require_relative '../clients/claude_client'

module VectorVault
  class EmbeddingService
    attr_reader :search_count

    def initialize(store, claude_client: nil)
      @store = store
      @claude_client = claude_client || MockClaudeClient.new
      @search_count = 0
    end

    def add(collection_id:, text:, metadata: {})
      collection = @store[:collections][collection_id]
      return nil unless collection

      vector = @claude_client.generate_embedding(text, dimension: collection.dimension)
      embedding = Embedding.new(
        collection_id: collection_id,
        text: text,
        vector: vector,
        metadata: metadata
      )
      @store[:embeddings][collection_id] << embedding
      embedding
    end

    def list(collection_id)
      @store[:embeddings][collection_id] || []
    end

    def search(query:, collection_id:, top_k: 5)
      collection = @store[:collections][collection_id]
      return nil unless collection

      embeddings = @store[:embeddings][collection_id] || []
      return [] if embeddings.empty?

      query_vector = @claude_client.generate_embedding(query, dimension: collection.dimension)

      results = embeddings.map do |emb|
        score = cosine_similarity(query_vector, emb.vector)
        SearchResult.new(
          embedding_id: emb.id,
          text: emb.text,
          score: score.round(6),
          metadata: emb.metadata
        )
      end

      @search_count += 1

      results.sort_by { |r| -r.score }.first(top_k)
    end

    def total_embeddings
      @store[:embeddings].values.flatten.size
    end

    private

    def cosine_similarity(vec_a, vec_b)
      return 0.0 if vec_a.nil? || vec_b.nil? || vec_a.empty? || vec_b.empty?

      dot_product = vec_a.zip(vec_b).map { |a, b| a * b }.sum
      mag_a = Math.sqrt(vec_a.map { |v| v * v }.sum)
      mag_b = Math.sqrt(vec_b.map { |v| v * v }.sum)

      return 0.0 if mag_a.zero? || mag_b.zero?

      dot_product / (mag_a * mag_b)
    end
  end
end
