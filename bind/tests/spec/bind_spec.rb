require 'net/http'
require 'uri'

require 'serverspec'
set :backend, :exec

describe service('bind9') do
  it { should be_enabled   }
  it { should be_running   }
end

describe port(53) do
  it { should be_listening }
end
