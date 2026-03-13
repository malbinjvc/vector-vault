# frozen_string_literal: true

require_relative '../models/cluster_result'

module VectorVault
  class ClusterService
    def initialize(store)
      @store = store
    end

    # K-means-like clustering of embeddings within a collection.
    # Returns an array of ClusterResult objects.
    def cluster(collection_id:, k: 3, max_iterations: 50)
      collection = @store[:collections][collection_id]
      return nil unless collection

      embeddings = @store[:embeddings][collection_id] || []
      return [] if embeddings.empty?

      # If fewer embeddings than clusters, reduce k
      k = [k, embeddings.size].min

      # Initialize centroids by picking the first k embeddings' vectors
      centroids = embeddings.first(k).map { |e| e.vector.dup }

      assignments = Array.new(embeddings.size, 0)

      max_iterations.times do
        new_assignments = embeddings.each_with_index.map do |emb, _idx|
          distances = centroids.map { |c| euclidean_distance(emb.vector, c) }
          distances.each_with_index.min_by { |d, _| d }.last
        end

        break if new_assignments == assignments

        assignments = new_assignments

        # Recompute centroids
        k.times do |cluster_idx|
          members = embeddings.each_with_index
                              .select { |_, idx| assignments[idx] == cluster_idx }
                              .map(&:first)
          next if members.empty?

          dimension = members.first.vector.size
          centroid = Array.new(dimension, 0.0)
          members.each do |m|
            m.vector.each_with_index { |v, i| centroid[i] += v }
          end
          centroids[cluster_idx] = centroid.map { |v| v / members.size }
        end
      end

      # Build results
      k.times.map do |cluster_idx|
        members = embeddings.each_with_index
                            .select { |_, idx| assignments[idx] == cluster_idx }
                            .map(&:first)

        cluster_members = members.map do |emb|
          dist = euclidean_distance(emb.vector, centroids[cluster_idx])
          ClusterMember.new(
            embedding_id: emb.id,
            text: emb.text,
            distance: dist.round(6)
          )
        end

        ClusterResult.new(
          cluster_id: cluster_idx,
          centroid: centroids[cluster_idx].map { |v| v.round(6) },
          members: cluster_members
        )
      end
    end

    private

    def euclidean_distance(vec_a, vec_b)
      Math.sqrt(vec_a.zip(vec_b).map { |a, b| (a - b)**2 }.sum)
    end
  end
end
