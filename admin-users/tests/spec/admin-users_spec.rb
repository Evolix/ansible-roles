require 'net/http'
require 'uri'

require 'serverspec'
set :backend, :exec

describe service('bind9') do
  it { should be_enabled   }
end

describe port(53) do
  it { should be_listening }
end

describe command("ps auwx | grep bind") do
  its(:stdout) { should include " -t /var/chroot-bind" }
end
