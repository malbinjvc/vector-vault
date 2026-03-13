# frozen_string_literal: true

require 'sinatra/base'
require 'json'
require 'securerandom'

require_relative 'models/collection'
require_relative 'models/embedding'
require_relative 'models/search_result'
require_relative 'models/cluster_result'
require_relative 'clients/claude_client'
require_relative 'services/collection_service'
require_relative 'services/embedding_service'
require_relative 'services/cluster_service'

module VectorVault
  class App < Sinatra::Base
    configure do
      set :port, 8080
      set :bind, '0.0.0.0'
      set :show_exceptions, false

      # In-memory data store
      store = {
        collections: {},
        embeddings: {}
      }
      set :store, store
      set :collection_service, CollectionService.new(store)
      set :embedding_service, EmbeddingService.new(store)
      set :cluster_service, ClusterService.new(store)
    end

    before do
      content_type :json
    end

    # ---------- Health ----------

    get '/health' do
      { status: 'ok', service: 'vector-vault', timestamp: Time.now.utc.iso8601 }.to_json
    end

    # ---------- Collections ----------

    post '/api/collections' do
      body = parse_json_body
      return error_response(400, 'name is required') unless body['name'] && !body['name'].strip.empty?

      collection = settings.collection_service.create(
        name: body['name'],
        description: body['description'] || '',
        dimension: (body['dimension'] || 100).to_i
      )

      status 201
      { data: collection.to_h }.to_json
    end

    get '/api/collections' do
      collections = settings.collection_service.list.map(&:to_h)
      { data: collections, count: collections.size }.to_json
    end

    get '/api/collections/:id' do
      collection = settings.collection_service.find(params[:id])
      return error_response(404, 'Collection not found') unless collection

      embedding_count = settings.embedding_service.list(params[:id]).size
      { data: collection.to_h.merge(embedding_count: embedding_count) }.to_json
    end

    delete '/api/collections/:id' do
      collection = settings.collection_service.delete(params[:id])
      return error_response(404, 'Collection not found') unless collection

      { data: { id: collection.id, deleted: true } }.to_json
    end

    # ---------- Embeddings ----------

    post '/api/collections/:id/embeddings' do
      collection = settings.collection_service.find(params[:id])
      return error_response(404, 'Collection not found') unless collection

      body = parse_json_body
      return error_response(400, 'text is required') unless body['text'] && !body['text'].strip.empty?

      embedding = settings.embedding_service.add(
        collection_id: params[:id],
        text: body['text'],
        metadata: body['metadata'] || {}
      )

      status 201
      { data: embedding.to_h }.to_json
    end

    get '/api/collections/:id/embeddings' do
      collection = settings.collection_service.find(params[:id])
      return error_response(404, 'Collection not found') unless collection

      embeddings = settings.embedding_service.list(params[:id]).map(&:to_h)
      { data: embeddings, count: embeddings.size }.to_json
    end

    # ---------- Search ----------

    post '/api/search' do
      body = parse_json_body
      return error_response(400, 'query is required') unless body['query'] && !body['query'].strip.empty?
      return error_response(400, 'collection_id is required') unless body['collection_id'] && !body['collection_id'].strip.empty?

      collection = settings.collection_service.find(body['collection_id'])
      return error_response(404, 'Collection not found') unless collection

      top_k = (body['top_k'] || 5).to_i
      results = settings.embedding_service.search(
        query: body['query'],
        collection_id: body['collection_id'],
        top_k: top_k
      )

      { data: results.map(&:to_h), count: results.size }.to_json
    end

    # ---------- Cluster ----------

    post '/api/cluster' do
      body = parse_json_body
      return error_response(400, 'collection_id is required') unless body['collection_id'] && !body['collection_id'].strip.empty?

      collection = settings.collection_service.find(body['collection_id'])
      return error_response(404, 'Collection not found') unless collection

      k = (body['k'] || 3).to_i
      clusters = settings.cluster_service.cluster(
        collection_id: body['collection_id'],
        k: k
      )

      { data: clusters.map(&:to_h), count: clusters.size }.to_json
    end

    # ---------- Stats ----------

    get '/api/stats' do
      {
        data: {
          total_collections: settings.collection_service.count,
          total_embeddings: settings.embedding_service.total_embeddings,
          total_searches: settings.embedding_service.search_count
        }
      }.to_json
    end

    # ---------- Error handling ----------

    not_found do
      error_response(404, 'Not found')
    end

    error do
      error_response(500, 'Internal server error')
    end

    private

    def parse_json_body
      request.body.rewind
      raw = request.body.read
      return {} if raw.empty?

      JSON.parse(raw)
    rescue JSON::ParserError
      {}
    end

    def error_response(code, message)
      status code
      { error: { code: code, message: message } }.to_json
    end

    # Start the server if run directly
    run! if app_file == $PROGRAM_NAME
  end
end
