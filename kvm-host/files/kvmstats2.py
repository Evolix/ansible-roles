#!/usr/bin/python3
# Dependencies:
# apt install python3-rbd python3-rados python3-tabulate

# Standard library
import subprocess, sys
import json
import xml.etree.ElementTree as xml
from dataclasses import dataclass
from typing import List
import argparse
import socket
import datetime

# Deps
import libvirt, rbd
from tabulate import tabulate

'''
TODO
- Trier la liste des VGs
- Gérer QCOW
- Accepter vm_name en argument
- Sortie JSON et kvmstats "all in one" style https://winnie.evolix.net/bkctlstats/
- Montrer les volumes logiques orphelins (nécessite de checker s'il sont utilisés sur un jumeau)
'''

hostname = socket.gethostname()
timestamp = datetime.datetime.now().replace(microsecond=0)
args_output = None

def bold(to_bold):
    if type(to_bold) is list:
        return [bold(item) for item in to_bold]
    else:
        if args_output == 'html':
            return str(to_bold)
        else:
            return '\033[1m' + str(to_bold) + '\033[0m'

def get_rbd_size(rbd_name: str, cluster: str = None):
    size_gib = '?'
    cmd = 'rbd --format json du {}'.format(rbd_name)
    if cluster:
        cmd += ' --cluster {}'.format(cluster)
    output = subprocess.run(cmd.split(), capture_output=True)
    if output.stdout:
        stdout = output.stdout.decode('utf-8')
        size_b = json.loads(stdout)['images'][0]['provisioned_size']
        size_gib = int(size_b / pow(1024,3))
    elif output.stderr:
        stderr = output.stderr.decode('utf-8')
        if 'not found' in stderr:
            size_gib = 'not found'
    return size_gib

def get_drbd_volumes(resource_name: str):
    volumes = {}
    cmd = 'drbdadm dump-xml {}'.format(resource_name)
    output = subprocess.run(cmd.split(), capture_output=True)
    if output.stdout:
        conf_root = xml.fromstring(output.stdout)
        for host in conf_root:
            if host.attrib['name'] == hostname:
                for volume in host.findall('volume'):
                    number = volume.attrib['vnr']
                    lvm_path = volume.find('disk').text
                    volumes[number] = lvm_path
    elif output.stderr:
        stderr = output.stderr.decode('utf-8')
        raise RuntimeError(stderr)
    return volumes

def sum2str(items: List, max_dislay: int = 2):
    if len(items) <= max_dislay:
        items = map(str, items)
        return '+'.join(items)
    try:
        total = sum(items)
    except:
        total = '?'
    return '{}+{}+…={}'.format(items[0], items[1], total)


class VG:
    def __init__(self, name: str, size_gib: int, allocated: int, running: int):
        self.name = name
        self.size_gib = size_gib
        self.allocated = allocated
        self.running = running

class LV:
    def __init__(self, name: str, vg: VG, size_gib: str):
        self.size_gib = size_gib
        self.vg = vg

@dataclass
class RBD:
    name: str
    ceph_cluster_version: int
    size_gib: str

@dataclass
class VM:
    name: str
    state: str
    cpus: int
    mem_gib: int
    lvs: List[LV]
    rbds: List[RBD]


ceph_v1_hosts = ['ceph01', 'ceph01.evolix.net', 'ceph02', 'ceph02.evolix.net', 'ceph03', 'ceph03.evolix.net',
                '31.170.11.105', '31.170.11.106','31.170.11.107']
ceph_v2_hosts = ['ceph10', 'ceph10.evolix.net', 'ceph11', 'ceph11.evolix.net', 'ceph12', 'ceph12.evolix.net', 'ceph13', 'ceph13.evolix.net',
                '31.170.8.129', '31.170.8.130', '185.236.226.131', '185.236.226.132',
                '192.168.31.10', '192.168.31.11', '192.168.31.12', '192.168.31.13']

# Libvirt VM states
state_dict = { # https://libvirt.org/html/libvirt-libvirt-domain.html#virDomainState
    0: 'no state', 1: 'running', 2: 'blocked on ressource', 3: 'paused',
    4: 'shutting down', 5: 'shut off', 6: 'crashed', 7: 'suspended'
}


# Parse the command-line arguments
parser = argparse.ArgumentParser(prog='kvmstats2.py')
parser.add_argument('-o', '--output', default='table', help='Output format, values: table (default), html')
args = parser.parse_args()
args_output = args.output

# List volume groups
vgs = {}
command = 'vgs --noheadings --options name,vg_size,vg_free --unit g'
output = subprocess.run(command.split(), capture_output=True)
if output.stdout:
    vg_infos = output.stdout.decode('utf-8').splitlines()
    for line in vg_infos:
        vg_name, size, free = line.strip().split()
        vg_size = int(round(float(size.strip('Gg')), 2))
        vg_allocated = int(round(float(size.strip('Gg')) - float(free.strip('Gg')), 2))
        vg_running = 0
        vg = VG(vg_name, vg_size, vg_allocated, vg_running)
        vgs[vg_name] = vg

# List logical volumes
lvs = {}
command = 'lvs --options vg_name,lv_name,lv_size --unit g --reportformat json'
output = subprocess.run(command.split(), capture_output=True)
if output.stdout:
    stdout = output.stdout.decode('utf-8')
    lv_list = json.loads(stdout)['report'][0]['lv']
    for lv in lv_list:
        size_gib = int(round(float(lv['lv_size'].strip('Gg')), 2))
        key = lv['vg_name'] + '/' + lv['lv_name']
        vg = vgs[lv['vg_name']]
        lvs[key] = (LV(lv['lv_name'], vg, size_gib))

ceph_v1, ceph_v2 = 'ceph v1', 'ceph v2'
ceph_clusters = []

# List libvirt domain IDs
try:
    conn = libvirt.open()
    domain_ids = conn.listDomainsID()  # running domains
except libvirt.libvirtError:
    print('Failed to open connection to the hypervisor')
    sys.exit(1)
except:
    print('Failed to find any domains')
    sys.exit(1)

# List running VM names
vm_names = []
for domain_id in domain_ids:
    vm = conn.lookupByID(domain_id)
    vm_name = vm.name()
    vm_names.append(vm_name)

# List inactive VM names
vm_names.extend(conn.listDefinedDomains())

# Get and parse VM XML definitions
vms = {}
for vm_name in vm_names:
    vm = conn.lookupByName(vm_name)
    vm_root = xml.fromstring(vm.XMLDesc())

    state, _, mem_kib, cpus, _ = vm.info()
    state = state_dict[state]
    mem_gib = int(round(mem_kib / 1024 / 1024, 2))

    # Gather infos on volumes
    vm_lvs = []  # list LV objects
    vm_rbds = []  # list RBD objects
    for device in vm_root.find('devices').findall('disk'):
        sources = device.findall('source')
        for source in sources:
            # DRBD and/or LVM
            if 'dev' in source.attrib:
                path = source.attrib['dev'].split('/')
                lv, vg = None, None
                if 'drbd' in path:
                    if 'by-disk' in path:
                        vg, lv = path[4], path[5] # format: /dev/drbd/by-disk/VG/LV
                    elif 'drbd' in path and 'by-res' in path:
                        ressource, number = path[4], path[5] # format: /dev/drbd/by-res/RESSOURCE/NUMBER
                        volumes = get_drbd_volumes(ressource)
                        path = volumes[number].split('/') # hopefully /dev/VG/LV
                if len(path) == 4:
                    vg, lv = path[2], path[3] # format: /dev/VG/LV
                try:
                    key = vg + '/' + lv
                except:
                    print('Unknow type of disk source: {}'.format(source.attrib['dev']), file=sys.stderr, flush=True)
                    continue
                if key not in lvs: continue
                vm_lvs.append(lvs[key])

            # Ceph/RBD
            elif 'protocol' in source.attrib and source.attrib['protocol'] == 'rbd':
                rbd_name = source.attrib['name'].split('/')[1]
                cluster_version = None
                for host in source.findall('host'):
                    if host.attrib['name'] in ceph_v1_hosts:
                        cluster_version = ceph_v1
                        break
                    if host.attrib['name'] in ceph_v2_hosts:
                        cluster_version = ceph_v2
                        break
                if cluster_version not in [ceph_v1, ceph_v2]:
                    print('RBD {}: could not identify Ceph cluster version.'.format(rbd_name), file=sys.stderr, flush=True)
                    continue

                rbd_size_gib = '?'
                if cluster_version == ceph_v1:
                    rbd_size_gib = get_rbd_size(rbd_name, 'ceph')
                elif cluster_version == ceph_v2:
                    rbd_size_gib = get_rbd_size(rbd_name, 'cephv2')

                vm_rbds.append(RBD(rbd_name, cluster_version, rbd_size_gib))
                if cluster_version not in ceph_clusters:
                    ceph_clusters.append(cluster_version)

    vms[vm_name] = VM(vm_name, state, cpus, mem_gib, vm_lvs, vm_rbds)


# Cumulate and compute

vcpus_running, vcpus_allocated = 0, 0
mem_running, mem_allocated = 0, 0
n_running = 0
for vm_name, vm in vms.items():
    # Cumulate into allocated and running counts
    vcpus_allocated += vm.cpus
    mem_allocated += vm.mem_gib
    if vm.state == 'running':
        n_running += 1
        vcpus_running += vm.cpus
        mem_running += vm.mem_gib
        for lv in vm.lvs:
            vgs[lv.vg.name].running += lv.size_gib

# Output

ceph_clusters.sort()

table = []
for vm_name, vm in vms.items():
    row = [vm_name, vm.cpus, vm.mem_gib]
    for vg_name, vg in vgs.items():
        vg_used_gib = [lv.size_gib for lv in vm.lvs if lv.vg == vg]
        row.append(sum2str(vg_used_gib))
    for cluster_version in ceph_clusters:
        rbds_sizes_gib = [rbd.size_gib for rbd in vm.rbds if rbd.ceph_cluster_version == cluster_version]
        for rbd in vm.rbds:
            if rbd.ceph_cluster_version == cluster_version:
                rbd_name = rbd.name
        row.append(sum2str(rbds_sizes_gib))

    row.append(vm.state)
    table.append(row)

table.sort()

header = ['VM', 'vCPUs', 'RAM']
header.extend(sorted(vgs.keys()))
header.extend(ceph_clusters)
header.append('state')

footer1 = ['TOTAL RUNNING', vcpus_running, mem_running]
footer1.extend([vgs[vg].running for vg in sorted(vgs.keys())])
footer1.append(n_running)

footer2 = ['TOTAL ALLOCATED', vcpus_allocated, mem_allocated]
footer2.extend([vgs[vg].allocated for vg in sorted(vgs.keys())])
footer2.append('')

footer3 = ['TOTAL RESSOURCES', conn.getInfo()[2], round(conn.getInfo()[1] / 1024)]
footer3.extend([vgs[vg].size_gib for vg in sorted(vgs.keys())])
footer3.append('')

for footer in [footer1, footer2, footer3]:
    table.append(bold(footer))

timestamp_msg = 'Generated at {}'.format(str(timestamp))

if args.output == 'table':
    print(timestamp)
    print(tabulate(table, headers=bold(header)))

elif args.output == 'html':
    print('<p>Generated at {}</p>'.format(str(timestamp)))
    print(tabulate(table, headers=bold(header), tablefmt='html'))

else:
    print('Option --output {} not supported.'.format(output), file=sys.stderr, flush=True)
    exit(1)
