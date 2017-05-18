require 'net/http'
require 'uri'

require 'serverspec'
set :backend, :exec

describe port(11211) do
  it { should be_listening }
end
