# frozen_string_literal: true

module Cnfs
  class Urn
    attr_accessor :txt, :partition_name, :service_name, :region, :account_id, :resource

    # rubocop:disable Metrics/ParameterLists
    def initialize(txt, partition_name, service_name, region = '*', account_id = '*', resource = '')
      @txt = txt
      @partition_name = partition_name
      @service_name = service_name
      @region = region
      @account_id = account_id
      @resource = resource
    end
    # rubocop:enable Metrics/ParameterLists

    def self.from_urn(urn_string)
      return nil unless urn_string

      urn_array = urn_string.split(':')
      new(*urn_array)
    end

    def self.from_jwt(token)
      jwt = Jwt.new(token)
      return unless (urn_string = jwt.decode['sub'])

      from_urn(urn_string)

    # NOTE: Intentionally swallow decode error and return nil
    rescue JWT::DecodeError
      nil
    end

    def resource_type
      resource.split('/').first
    end

    def resource_id
      resource.split('/').last
    end

    def model_name
      resource_type.classify
    end

    def model
      model_name.constantize
    end

    def instance
      model.find_by_urn(resource_id)
    end

    def to_s
      [txt, partition_name, service_name, region, account_id, resource].join(':')
    end

    # urn:partition:service:region:account-id:resource-type/resource-id
    def match(other_urn)
      other = self.class.from_urn(other_urn)
      %i[txt partition_name].each do |urn_attr|
        # return unless send(urn_attr).eql?(other.send(urn_attr))
        return false unless other.send(urn_attr).eql?(send(urn_attr))
      end
      %i[region account_id].each do |urn_attr|
        next if other.send(urn_attr).empty? || other.send(urn_attr).eql?('*')

        return false unless other.send(urn_attr).eql?(send(urn_attr))
      end
      true
    end
  end
end
