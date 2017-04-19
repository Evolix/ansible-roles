require 'net/http'
require 'uri'

require 'serverspec'
set :backend, :exec

describe file('/etc/.git/config') do
  it { should be_file   }
end

describe command("cd /git && git status --porcelain") do
  its(:stdout) { should be_empty }
end

describe command("cd /git && git log --oneline") do
  its(:exit_status) { should eq 0 }
end
