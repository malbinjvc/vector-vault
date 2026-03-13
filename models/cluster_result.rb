# frozen_string_literal: true

module VectorVault
  class ClusterResult
    attr_reader :cluster_id, :centroid, :members

    def initialize(cluster_id:, centroid:, members:)
      @cluster_id = cluster_id
      @centroid = centroid
      @members = members
    end

    def to_h
      {
        cluster_id: @cluster_id,
        centroid: @centroid,
        members: @members.map(&:to_h)
      }
    end
  end

  class ClusterMember
    attr_reader :embedding_id, :text, :distance

    def initialize(embedding_id:, text:, distance:)
      @embedding_id = embedding_id
      @text = text
      @distance = distance
    end

    def to_h
      {
        embedding_id: @embedding_id,
        text: @text,
        distance: @distance
      }
    end
  end
end
