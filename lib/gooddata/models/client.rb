# encoding: UTF-8
#
# Copyright (c) 2010-2017 GoodData Corporation. All rights reserved.
# This source code is licensed under the BSD-style license found in the
# LICENSE file in the root directory of this source tree.

require_relative '../rest/resource'

require_relative '../mixins/data_property_reader'
require_relative '../mixins/links'
require_relative '../mixins/rest_resource'
require_relative '../mixins/uri_getter'

module GoodData
  class Client < Rest::Resource
    data_property_reader 'id'

    attr_accessor :domain

    include Mixin::Links
    include Mixin::UriGetter

    CLIENT_TEMPLATE = {
      client: {
        id: nil,
        segment: nil,
        project: nil
      }
    }

    class << self
      def [](id, opts = {})
        domain = opts[:domain]
        segment = opts[:segment]
        fail ArgumentError, 'No :domain specified' if domain.nil?
        fail ArgumentError, 'No :segment specified' if domain.nil?

        client = domain.client
        fail ArgumentError, 'No client specified' if client.nil?

        if id == :all
          tenants_uri = domain.segments_uri + "/clients?segment=#{CGI.escape(segment.segment_id)}"
          Enumerator.new do |y|
            loop do
              res = client.get tenants_uri
              res['clients']['paging']['next']
              res['clients']['items'].each do |i|
                p = i['client']['project']
                tenant = client.create(GoodData::Client, i.merge('domain' => domain))
                tenant.project = p
                y << tenant
              end
              url = res['clients']['paging']['next']
              break unless url
            end
          end
        else
          id = id.respond_to?(:client_id) ? id.client_id : id
          data = client.get(domain.segments_uri + "/clients/#{CGI.escape(id)}")
          client.create(GoodData::Client, data.merge('domain' => domain))
        end
      end

      # Creates new client from parameters passed.
      #
      # Should not be called directly. Use GoodData::Segment#create_client.
      #
      # @param data [Hash] Data required to create the client
      # @option data id [String]
      # @option data project [GoodData::Project]
      # @param options [Hash] Options
      # @option options segment [GoodData::Segment]
      # @option options client [GoodData::Rest::Client]
      # @return [GoodData::Client] New GoodData::Client instance
      def create(data, options)
        segment = options[:segment]
        domain = segment.domain
        tenant = client.create(GoodData::Client, GoodData::Helpers.stringify_keys(CLIENT_TEMPLATE.merge(domain: domain)), domain: domain)
        tenant.tap do |s|
          s.project = data[:project]
          s.client_id = data[:id]
          s.segment = segment.uri
        end
      end

      def update_setting(name, value, opts = {})
        return nil unless value
        domain = opts[:domain]
        client_id = opts[:client_id]
        uri = "#{domain.segments_uri}/clients/#{client_id}/settings/#{name}"
        body = {
          setting: {
            name: "#{name}",
            value: "#{value}"
          }
        }
        domain.client.put(uri, body)
        nil
      end
      alias_method :add_setting, :update_setting
    end

    def initialize(data)
      super(data)
      @domain = data.delete('domain')
      @json = data
    end

    # Segment id getter for the Segment. Called segment_id since id is a reserved word in ruby world
    #
    # @return [String] Segment id
    def client_id
      data['id']
    end

    def client_id=(a_name)
      data['id'] = a_name
      self
    end

    # Setter for the project this client has set
    #
    # @param a_project [String|GoodData::Project] Id or an instance of a project
    # @return [GoodData::Cliet] Returns the instance of the client
    def project=(a_project)
      data['project'] = a_project.respond_to?(:uri) ? a_project.uri : a_project
      self
    end

    # Project URI this client has set
    #
    # @return [String] Returns the URI of the project this client has set
    def project_uri
      data['project']
    end

    # Project this client has set
    #
    # @return [GoodData::Project] Returns the instance of the client's project
    def project
      client.projects(project_uri) if project?
    end

    # Returns boolean if client has a project provisioned
    #
    # @return [Boolean] Returns true if client has a project provisioned. False otherwise
    def project?
      project_uri != nil
    end

    # Reloads the client from the URI
    #
    # @return [GoodData::Client] Returns the updated client object
    def reload!
      res = client.get(uri)
      @json = res
      self
    end

    # Segment id setter which this client is connected to.
    #
    # @param a_segment [String] Id of the segment.
    # @return [GoodData::Client] Returns the instance of the client
    def segment=(a_segment)
      data['segment'] = a_segment.respond_to?(:uri) ? a_segment.uri : a_segment
      self
    end

    # Segment this client is connected to.
    #
    # @return [GoodData::Segment] Segment
    def segment
      segment_res = client.get(data['segment'])
      client.create(GoodData::Segment, segment_res)
    end

    # Segment URI this client is connected to.
    #
    # @return [String] Segment URI
    def segment_uri
      data['segment']
    end

    # Creates or updates a client instance on the API.
    #
    # @return [GoodData::Client] Client instance
    def save
      if uri
        client.put(uri, json)
      else
        res = client.post(domain.segments_uri + '/clients', json)
        @json = res
      end
      self
    end

    # Deletes a client instance on the API.
    #
    # @return [GoodData::Client] Segment instance
    def delete
      project.delete if project && !project.deleted?
      client.delete(uri) if uri
    end

    def settings
      uri = "#{domain.segments_uri}/clients/#{client_id}/settings"
      res = client.get(uri)
      settings = GoodData::Helpers.get_path(res, %w(settingsList items))
      settings.map do |setting|
        setting = setting['setting']
        {
          name: setting['name'],
          value: setting['value']
        }
      end
    end
  end
end
