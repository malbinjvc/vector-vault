# frozen_string_literal: true

module VectorVault
  class Embedding
    attr_reader :id, :collection_id, :text, :vector, :metadata, :created_at

    def initialize(collection_id:, text:, vector:, metadata: {})
      @id = SecureRandom.uuid
      @collection_id = collection_id
      @text = text
      @vector = vector
      @metadata = metadata
      @created_at = Time.now.utc.iso8601
    end

    def to_h
      {
        id: @id,
        collection_id: @collection_id,
        text: @text,
        vector: @vector,
        metadata: @metadata,
        created_at: @created_at
      }
    end
  end
end
