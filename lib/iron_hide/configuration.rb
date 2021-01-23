# frozen_string_literal: true

module IronHide
  class Configuration
    attr_accessor :adapter, :namespace, :json, :memoize, :resolver

    def initialize
      @adapter   = :cnfs_file
      @namespace = 'com::IronHide'
      @memoize   = true
      @resolver  = :urn
    end

    def memoizer
      memoize ? SimpleCache : NullCache
    end

    # Extend configuration variables
    #
    # @param config_hash [Hash]
    #
    # @example
    #   IronHide.configuration.add_configuration(couchdb_server: 'http://127.0.0.1:5984')
    #   IronHide.configuration.couchdb_server)
    #   #=> 'http://127.0.0.1:5984'
    #
    #   IronHide.configuration.couchdb_server = 'other'
    #   #=> 'other'
    #
    def add_configuration(config_hash)
      config_hash.each do |key, val|
        instance_eval { instance_variable_set("@#{key}", val) }
        self.class.instance_eval { attr_accessor key }
      end
    end
  end
end
