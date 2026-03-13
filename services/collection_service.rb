# frozen_string_literal: true

require_relative '../models/collection'

module VectorVault
  class CollectionService
    def initialize(store)
      @store = store
    end

    def create(name:, description: '', dimension: 100)
      collection = Collection.new(name: name, description: description, dimension: dimension)
      @store[:collections][collection.id] = collection
      @store[:embeddings][collection.id] = []
      collection
    end

    def list
      @store[:collections].values
    end

    def find(id)
      @store[:collections][id]
    end

    def delete(id)
      collection = @store[:collections].delete(id)
      @store[:embeddings].delete(id) if collection
      collection
    end

    def count
      @store[:collections].size
    end
  end
end
