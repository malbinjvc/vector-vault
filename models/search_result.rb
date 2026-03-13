# frozen_string_literal: true

module VectorVault
  class SearchResult
    attr_reader :embedding_id, :text, :score, :metadata

    def initialize(embedding_id:, text:, score:, metadata: {})
      @embedding_id = embedding_id
      @text = text
      @score = score
      @metadata = metadata
    end

    def to_h
      {
        embedding_id: @embedding_id,
        text: @text,
        score: @score,
        metadata: @metadata
      }
    end
  end
end
