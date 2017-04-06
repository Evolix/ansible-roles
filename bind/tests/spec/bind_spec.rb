require 'net/http'
require 'uri'

require 'serverspec'
set :backend, :exec

describe port(53) do
  it { should be_listening }
end
