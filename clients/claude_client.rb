# frozen_string_literal: true

module VectorVault
  # Abstract base class for Claude API clients
  class ClaudeClient
    def generate_embedding(text, dimension: 100)
      raise NotImplementedError, 'Subclasses must implement generate_embedding'
    end
  end

  # Mock Claude client that returns deterministic bag-of-words vectors.
  # No real API calls are made. The vector is built from word frequency
  # counts mapped to fixed dimension slots via a hash function.
  class MockClaudeClient < ClaudeClient
    def generate_embedding(text, dimension: 100)
      return Array.new(dimension, 0.0) if text.nil? || text.strip.empty?

      # Tokenize: downcase, split on non-word characters, remove blanks
      words = text.downcase.gsub(/[^a-z0-9\s]/, '').split(/\s+/).reject(&:empty?)

      # Build bag-of-words vector
      vector = Array.new(dimension, 0.0)

      words.each do |word|
        # Deterministic slot assignment using a simple hash
        slot = word_hash(word) % dimension
        vector[slot] += 1.0
      end

      # L2-normalize the vector so cosine similarity works well
      magnitude = Math.sqrt(vector.map { |v| v * v }.sum)
      if magnitude > 0.0
        vector.map { |v| v / magnitude }
      else
        vector
      end
    end

    private

    # Simple deterministic hash for a word (FNV-1a inspired)
    def word_hash(word)
      hash = 2_166_136_261
      word.each_byte do |byte|
        hash ^= byte
        hash = (hash * 16_777_619) & 0xFFFFFFFF
      end
      hash
    end
  end
end
