# frozen_string_literal: true

ENV['RACK_ENV'] = 'test'

# Add vendor gems to load path (minitest is Ruby 4.0 stdlib, no bundler needed)
vendor = File.expand_path('../vendor/bundle/ruby/4.0.0/gems', __dir__)
Dir.glob("#{vendor}/*/lib").each { |p| $LOAD_PATH.unshift(p) } if Dir.exist?(vendor)

require 'minitest/autorun'
require 'rack/test'
require 'json'
require_relative '../app'

class VectorVaultAppTest < Minitest::Test
  include Rack::Test::Methods

  def app
    VectorVault::App
  end

  def setup
    # Reset in-memory store before each test
    store = app.settings.store
    store[:collections].clear
    store[:embeddings].clear
  end

  # ---------- Health ----------

  def test_health_check
    get '/health'
    assert_equal 200, last_response.status
    body = JSON.parse(last_response.body)
    assert_equal 'ok', body['status']
    assert_equal 'vector-vault', body['service']
    assert body.key?('timestamp')
  end

  # ---------- Collections ----------

  def test_create_collection
    post_json '/api/collections', { name: 'test-collection', description: 'A test', dimension: 50 }
    assert_equal 201, last_response.status
    body = JSON.parse(last_response.body)
    data = body['data']
    assert_equal 'test-collection', data['name']
    assert_equal 'A test', data['description']
    assert_equal 50, data['dimension']
    assert data['id']
  end

  def test_create_collection_missing_name
    post_json '/api/collections', { description: 'No name' }
    assert_equal 400, last_response.status
    body = JSON.parse(last_response.body)
    assert body['error']
    assert_includes body['error']['message'], 'name is required'
  end

  def test_list_collections
    post_json '/api/collections', { name: 'col-1' }
    post_json '/api/collections', { name: 'col-2' }
    get '/api/collections'
    assert_equal 200, last_response.status
    body = JSON.parse(last_response.body)
    assert_equal 2, body['count']
    assert_equal 2, body['data'].size
  end

  def test_get_collection
    post_json '/api/collections', { name: 'find-me' }
    created = JSON.parse(last_response.body)['data']

    get "/api/collections/#{created['id']}"
    assert_equal 200, last_response.status
    body = JSON.parse(last_response.body)
    assert_equal 'find-me', body['data']['name']
    assert_equal 0, body['data']['embedding_count']
  end

  def test_get_collection_not_found
    get '/api/collections/nonexistent-id'
    assert_equal 404, last_response.status
  end

  def test_delete_collection
    post_json '/api/collections', { name: 'delete-me' }
    created = JSON.parse(last_response.body)['data']

    delete "/api/collections/#{created['id']}"
    assert_equal 200, last_response.status
    body = JSON.parse(last_response.body)
    assert body['data']['deleted']

    # Verify it is gone
    get "/api/collections/#{created['id']}"
    assert_equal 404, last_response.status
  end

  def test_delete_collection_not_found
    delete '/api/collections/nonexistent-id'
    assert_equal 404, last_response.status
  end

  # ---------- Embeddings ----------

  def test_add_embedding
    col_id = create_collection('emb-test')

    post_json "/api/collections/#{col_id}/embeddings", { text: 'Hello world', metadata: { source: 'test' } }
    assert_equal 201, last_response.status
    body = JSON.parse(last_response.body)
    data = body['data']
    assert_equal 'Hello world', data['text']
    assert_equal col_id, data['collection_id']
    assert data['vector'].is_a?(Array)
    assert_equal 100, data['vector'].size
    assert_equal({ 'source' => 'test' }, data['metadata'])
  end

  def test_add_embedding_missing_text
    col_id = create_collection('emb-test-2')
    post_json "/api/collections/#{col_id}/embeddings", { metadata: {} }
    assert_equal 400, last_response.status
  end

  def test_add_embedding_collection_not_found
    post_json '/api/collections/nonexistent/embeddings', { text: 'orphan' }
    assert_equal 404, last_response.status
  end

  def test_list_embeddings
    col_id = create_collection('list-emb')
    post_json "/api/collections/#{col_id}/embeddings", { text: 'First text' }
    post_json "/api/collections/#{col_id}/embeddings", { text: 'Second text' }

    get "/api/collections/#{col_id}/embeddings"
    assert_equal 200, last_response.status
    body = JSON.parse(last_response.body)
    assert_equal 2, body['count']
  end

  # ---------- Search ----------

  def test_similarity_search
    col_id = create_collection('search-col')
    post_json "/api/collections/#{col_id}/embeddings", { text: 'Ruby programming language' }
    post_json "/api/collections/#{col_id}/embeddings", { text: 'Python programming language' }
    post_json "/api/collections/#{col_id}/embeddings", { text: 'Cooking recipes for dinner' }

    post_json '/api/search', { query: 'Ruby language', collection_id: col_id, top_k: 2 }
    assert_equal 200, last_response.status
    body = JSON.parse(last_response.body)
    assert_equal 2, body['count']
    # The top result should be "Ruby programming language" since the query shares the word "ruby"
    assert_equal 'Ruby programming language', body['data'][0]['text']
    # Scores should be descending
    assert body['data'][0]['score'] >= body['data'][1]['score']
  end

  def test_search_missing_query
    post_json '/api/search', { collection_id: 'abc' }
    assert_equal 400, last_response.status
  end

  def test_search_missing_collection_id
    post_json '/api/search', { query: 'test' }
    assert_equal 400, last_response.status
  end

  def test_search_collection_not_found
    post_json '/api/search', { query: 'test', collection_id: 'nonexistent' }
    assert_equal 404, last_response.status
  end

  def test_search_empty_collection
    col_id = create_collection('empty-search')
    post_json '/api/search', { query: 'anything', collection_id: col_id }
    assert_equal 200, last_response.status
    body = JSON.parse(last_response.body)
    assert_equal 0, body['count']
  end

  # ---------- Cluster ----------

  def test_cluster_embeddings
    col_id = create_collection('cluster-col')
    post_json "/api/collections/#{col_id}/embeddings", { text: 'machine learning algorithms' }
    post_json "/api/collections/#{col_id}/embeddings", { text: 'deep learning neural networks' }
    post_json "/api/collections/#{col_id}/embeddings", { text: 'cooking pasta recipes' }
    post_json "/api/collections/#{col_id}/embeddings", { text: 'baking bread at home' }

    post_json '/api/cluster', { collection_id: col_id, k: 2 }
    assert_equal 200, last_response.status
    body = JSON.parse(last_response.body)
    assert_equal 2, body['count']
    body['data'].each do |cluster|
      assert cluster.key?('cluster_id')
      assert cluster.key?('centroid')
      assert cluster.key?('members')
      assert cluster['centroid'].is_a?(Array)
    end
    # Total members across clusters should equal total embeddings
    total_members = body['data'].sum { |c| c['members'].size }
    assert_equal 4, total_members
  end

  def test_cluster_collection_not_found
    post_json '/api/cluster', { collection_id: 'nonexistent' }
    assert_equal 404, last_response.status
  end

  def test_cluster_missing_collection_id
    post_json '/api/cluster', {}
    assert_equal 400, last_response.status
  end

  # ---------- Stats ----------

  def test_stats
    col_id = create_collection('stats-col')
    post_json "/api/collections/#{col_id}/embeddings", { text: 'stat text one' }
    post_json "/api/collections/#{col_id}/embeddings", { text: 'stat text two' }
    post_json '/api/search', { query: 'stat', collection_id: col_id }

    get '/api/stats'
    assert_equal 200, last_response.status
    body = JSON.parse(last_response.body)
    data = body['data']
    assert_equal 1, data['total_collections']
    assert_equal 2, data['total_embeddings']
    assert data['total_searches'] >= 1
  end

  # ---------- 404 ----------

  def test_not_found_route
    get '/api/nonexistent'
    assert_equal 404, last_response.status
    body = JSON.parse(last_response.body)
    assert body['error']
  end

  # ---------- Mock Claude Client ----------

  def test_mock_client_deterministic
    client = VectorVault::MockClaudeClient.new
    vec1 = client.generate_embedding('hello world')
    vec2 = client.generate_embedding('hello world')
    assert_equal vec1, vec2
  end

  def test_mock_client_normalized
    client = VectorVault::MockClaudeClient.new
    vec = client.generate_embedding('test vector normalization')
    magnitude = Math.sqrt(vec.map { |v| v * v }.sum)
    assert_in_delta 1.0, magnitude, 0.001
  end

  def test_mock_client_different_texts_different_vectors
    client = VectorVault::MockClaudeClient.new
    vec1 = client.generate_embedding('ruby programming')
    vec2 = client.generate_embedding('cooking dinner')
    refute_equal vec1, vec2
  end

  private

  def post_json(path, data)
    post path, data.to_json, { 'CONTENT_TYPE' => 'application/json' }
  end

  def create_collection(name, dimension: 100)
    post_json '/api/collections', { name: name, dimension: dimension }
    JSON.parse(last_response.body)['data']['id']
  end
end
