require 'net/http'
require 'uri'

require 'serverspec'
set :backend, :exec

describe service('mongodb') do
  it { should be_enabled   }
end

describe port(27042) do
  it { should be_listening }
end

describe file("/var/log/mongo-test.log") do
  it { should be_file }
end

describe file("/var/run/mongodb.pid") do
  it { should be_file }
end
