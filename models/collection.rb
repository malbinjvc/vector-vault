# frozen_string_literal: true

module VectorVault
  class Collection
    attr_reader :id, :name, :description, :dimension, :created_at
    attr_accessor :updated_at

    def initialize(name:, description: '', dimension: 100)
      @id = SecureRandom.uuid
      @name = name
      @description = description
      @dimension = dimension
      @created_at = Time.now.utc.iso8601
      @updated_at = @created_at
    end

    def to_h
      {
        id: @id,
        name: @name,
        description: @description,
        dimension: @dimension,
        created_at: @created_at,
        updated_at: @updated_at
      }
    end
  end
end
