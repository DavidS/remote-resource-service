# frozen_string_literal: true

require 'spec_helper'
require 'puppet'
require 'puppet/resource/catalog'
require 'puppet/indirector/rest'
require 'puppet/indirector/catalog/certless'

RSpec.describe Puppet::Resource::Catalog::Certless do
  let(:indirector) { described_class.new }

  let(:request) { instance_double(Puppet::Indirector::Request, 'request') }
  let(:environment) { instance_double(Puppet::Node::Environment::Remote, 'environment') }
  let(:response_ok) { instance_double(Net::HTTPOK, 'response_ok') }
  let(:ssl_context) { instance_double(Puppet::SSL::SSLContext, 'ssl_context') }
  let(:http_pool) { instance_double(Puppet::Network::HTTP::NoCachePool, 'http_pool') }
  let(:http_connection) { instance_double(Puppet::Network::HTTP::Connection, 'http_connection') }
  let(:request_options) do
    {
      transport_facts: {
        "clientcert" => "foo.delivery.puppetlabs.net",
        "clientversion" => "6.4.0",
        "clientnoop" => false
      },
      trusted_facts: {
        authenticated: "remote",
        extensions: {},
        certname: "foo.delivery.puppetlabs.net",
        hostname: "foo",
        domain: "delivery.puppetlabs.net"
      },
      fail_on_404: true,
      transaction_uuid: "2078748407702309438222210184383400900",
      job_id: "271036342116034393375846637943780463672"
    }
  end
  let(:headers) do
    {
      'Content-Type' => 'text/json',
      'X-Puppet-Version' => '6.4.0',
      'Accept' => 'application/json'
    }
  end
  let(:response_success_body) do
    {
      "catalog": {
        "tags": [
          "settings",
          "foo.delivery.puppetlabs.net",
          "node"
        ],
        "name": "foo.delivery.puppetlabs.net",
        "version": 1554885119,
        "catalog_uuid": "0ee685b8-0802-4a2f-94a8-077abd65880d",
        "catalog_format": 1,
        "environment": "production",
        "resources": [],
        "edges": [],
        "classes": [
          "settings",
          "foo.delivery.puppetlabs.net"
        ]
      }
    }
  end

  let(:response_error_body) do
    "404"
  end

  describe '#headers' do
    before do
      allow(Puppet).to receive(:version).and_return('6.4.1')
    end

    it { expect(indirector.headers['Content-Type']).to eq 'text/json' }
    it { expect(indirector.headers['Accept']).to eq 'application/json' }
    it { expect(indirector.headers['X-Puppet-Version']).to eq '6.4.1' }
    it { expect(indirector.headers['accept-encoding']).to be_a String }
    it { expect(indirector.headers).to include('Content-Type', 'Accept', 'X-Puppet-Version', 'accept-encoding') }
  end

  describe '#find' do
    before do
      # all this set up is just to mock the
      # puppet api - yes it is horrendous
      allow(request).to receive(:key).and_return('foo.delivery.puppetlabs.net')
      allow(request).to receive(:environment).and_return(environment)
      allow(request).to receive(:options).and_return(request_options)
      allow(request).to receive(:server).and_return('localhost')
      allow(request).to receive(:port).and_return('9999')
      allow(environment).to receive(:name).and_return('environment')
      allow(request).to receive(:do_request) do |_, &block|
        block.call(request, '/foo', request_options.to_json, headers)
      end
      allow(Puppet).to receive(:lookup).with(:server).and_return('localhost')
      allow(Puppet).to receive(:lookup).with(:serverport).and_return('9999')
      allow(Puppet).to receive(:lookup).with(:http_pool).and_return(http_pool)
      allow(Puppet).to receive(:lookup).with(:ssl_context).and_return(ssl_context)
      allow(Puppet).to receive(:lookup).with(:ssl_agent_version).and_return('6.4.0')
      allow(Puppet).to receive(:lookup).with(:server_agent_version).and_return('6.4.0')
      allow(http_pool).to receive(:with_connection) do |_, &block|
        block.call(http_connection)
      end
      allow(http_connection).to receive(:request).and_return(response_ok)
      allow(response_ok).to receive(:message).and_return('ok')
      allow(response_ok).to receive(:[]).with('X-Puppet-Version').and_return('6.4.0')
      allow(response_ok).to receive(:[]).with('content-type').and_return('application/json')
      allow(response_ok).to receive(:[]).with('content-encoding')
    end

    it 'returns a Puppet Catalog on success' do
      allow(response_ok).to receive(:code).and_return('200')
      allow(response_ok).to receive(:body).and_return(response_success_body.to_json)
      expect(indirector.find(request)).to be_a Puppet::Resource::Catalog
    end

    it 'raises error on a 404' do
      allow(response_ok).to receive(:code).and_return('404')
      allow(response_ok).to receive(:body).and_return(response_error_body.to_json)
      expect { indirector.find(request) }.to raise_error(Puppet::Error, 'Find /puppet/v4/catalog '\
                                                                        'resulted in 404 with the message: "404"')
    end
  end
end
