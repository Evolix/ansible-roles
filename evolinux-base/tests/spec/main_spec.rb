require 'net/http'
require 'uri'

require 'serverspec'
set :backend, :exec

# describe file("/etc/apt/sources.list.d/backports.list") do
#   it { should be_file }
# end
#
# describe file("/etc/apt/preferences.d/0-backports-defaults") do
#   it { should be_file }
# end
#
# describe command("grep 'main contrib non-free' /etc/apt/sources.list.d/backports.list") do
#   its(:stdout) { should_not be_empty }
#   its(:exit_status) { should eq 0 }
# end
#
# describe command("grep 'main contrib non-free' /etc/apt/sources.list") do
#   its(:stdout) { should_not be_empty }
#   its(:exit_status) { should eq 0 }
# end
