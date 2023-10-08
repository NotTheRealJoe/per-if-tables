# per-if-tables
This is a script that can be called by NetworkManager to automatically create
and configure a Linux control group (cgroup) and routing table per-interface for
one or more interfaces you specify.

## Why
You have a system with more than one network interface. You want to route the
traffic from some processes on one interface, perhaps do the same with
additional process groups and interfaces, and then have the rest go over a
default interface. You don't need/want to fully containerize the processes or
use virtual machines.

## Pre-requisites
This script is fired by NetworkManager when it detects an IPv4 DHCP change, so
its only good if your system uses NetworkManager and you expect to get your
default routes over DHCP. If you aren't using DHCP you don't really need this.

You also need iproute2 and a kernel recent enough to support cgroups.

## How to use
- Copy `config.inc.sh.example` to a file named `config.inc.sh`
- Set SUB_TABLE_INTERFACES to an array of the interface names you want to create
  tables and cgroups for. Any interfaces NOT listed will have their routes go
  on the default table.
- Set OVERWRITE_RESOLVCONF to the content you want in /etc/resolv.conf after
  all interfaces are configured. Remember that since this isn't fully
  containerization, processes assigned to the non-default cgroup will have
  different routes but will be reading the *same* resolvconf. If you want all
  your interfaces to be able to resolve names, you will need a nameserver that
  can be accessed by all the interfaces. In most usecases, using a public
  nameserver accessible over the internet works well here.
- Run `install.sh`
- Bring your interfaces online using NetworkManager
- A cgroup named `sub_<interface name>` has been created for each of the
  interfaces you specified in SUB_TABLE_INTERFACES. To add processes to the
  cgroup and thus make them subject to that interface's routing, append the
  process ID(s) to `/sys/fs/cgroup/sub_<interface name>/cgroup.procs`.
- When you add a PID to one cgroup's file, it is automatically removed from all
  others. So you can move processes around by just adding the PID to the
  destination cgroup's `cgroup.procs`.
- To send a process back to the default cgroup and routing, just append its PID
  to `/sys/fs/cgroup/cgroup.procs`.

## How to uninstall
- Delete `/etc/NetworkManager/dispatcher.d/per-if-tables.sh`

## Isn't this the same thing as docker networks?
Mostly, yes. Docker does use cgroups to separate processes and provide routing,
at least in some network configurations. Using this script allows you to achieve
the ability to split processes across networks without having the processes
fully containerized. Processes will still have the same access to your
filesystem and other system resources as if you had run them normally.