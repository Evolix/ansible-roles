require 'net/http'
require 'uri'

require 'serverspec'
set :backend, :exec

describe user('foo') do
  it { should exist }
  it { should have_uid 1001 }
  it { should have_home_directory "/home/foo" }
  it { should have_authorized_key 'ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC/SeCzyf+Fguc5pBaWEYuETH/Db9VqFQmgWbSmNPC1pzLlzOhKiN2QMZeq1WLwr676myzHdKSFW2YY+C9PhdFWARXfYdzDogwvaxlNKprryruJ+MCTF0nXIO9AL3JtAgnSRBSYxTRQffA7QfroKs4hNu3lXVBM6OaMaIZUKy4/9pCldyDVFcMCH0efr0jSLuFRsXnwAhMEh90Qg9XFRaLK+GXD4Zvb/Pi0ExlS3X9ZpME0IX7enAfi2OAja4gPNTK+haKl2RrO3N2hlHCuSCiPem3secUmnLU1P8JyibO7iC44hgQD0vmtd5XBdDfz5K1us8RmxBCXobhidqsen/JN foo@localhost' }
  its(:encrypted_password) { should eq "$6$XFwV0M0b$hwArNeBI7jzp3Ykp14T.JTPoXLJx/Kbr3EQ0Seub4p9stgV/k9mLxlkltryaa3enZCpwGxY3n3oInAO1TrnJM." }
end
