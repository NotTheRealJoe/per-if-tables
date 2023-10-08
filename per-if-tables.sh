#!/bin/bash
function log {
	echo "[$(date)] $1" >> /var/log/per-if-tables.log
}

function rand-id {
	# Randomly generate a 4-digit numeric ID for use as ip rt_tables IDs
	# and fwmark valuesr
	echo $[ $RANDOM % 9999 + 1000]
}

function add-table-name {
	# Usage: add-table-name <ip route line> <table name>
	sed -E "s/(dev [^ ]* )/\1table $2 /" <<< "$1"
}

function table-exists {
	# Usage: table-exists <table name>
	if ip route show table "$1" 2>&1 > /dev/null; then
		return 0
	else
		return 1
	fi
}

function create-table {
	# Usage: create-table <table name> <interface name>
	mkdir /sys/fs/cgroup/$1
	FWMARK_VAL=$(rand-id)
	log "Creating table $1 with fwmark value $FWMARK_VAL"
	iptables -t mangle -A OUTPUT -m cgroup --path $1 -j MARK --set-mark $FWMARK_VAL
	iptables -t nat -A POSTROUTING -m cgroup --path $1 -o $2 -j MASQUERADE
	# I think the numeric ID for the table in rt_tables needs only be unique:
	# it doesn't have to be the same as the FWMARK_VAL, but might as well set
	# it to be the same so its easier to tell which tables and FWMARK_VALs
	# go together.
	echo "$FWMARK_VAL $1" >> /etc/iproute2/rt_tables
	ip rule add fwmark $FWMARK_VAL table $1
}

function move-route-to-table {
	# Usage: move-route-to-table <interface name>
	ROUTE_LINE="$(ip route | grep "default via .* dev $1 ")"
	log "Found generated route line $ROUTE_LINE"
	if [[ "$ROUTE_LINE" == "" ]]; then
		log "No default route found for $1; quitting"
		return 0
	fi
	TABLE="sub_$1"
	log "Using table name $TABLE"
	if ! table-exists $TABLE; then
		log "Had to create cgroup and table $TABLE"
		create-table $TABLE $1
	fi
	log "Executing ip route del $ROUTE_LINE"
	ip route del $ROUTE_LINE
	log "Executing ip route flush table $TABLE"
	ip route flush table $TABLE
	log "Executing ip route add $(add-table-name "$ROUTE_LINE" $TABLE)"
	ip route add $(add-table-name "$ROUTE_LINE" $TABLE)
}

INTERFACE=$1
EVENT=$2

log "Received event type $EVENT for interface $INTERFACE"

if [[ "$EVENT" != "dhcp4-change" ]]; then
	# dhcp4-change can be used to detect a change in the ipv4
	# routing tables. Its the only type of event we care about
	# for now.
	exit 0
fi

if [[ " ${SUB_TABLE_INTERFACES[*]} " =~ " ${INTERFACE} " ]]; then
	move-route-to-table "$INTERFACE"
fi

if [ -n "$OVERWRITE_RESOLVCONF" ]; then
	echo "$OVERWRITE_RESOLVCONF" > /etc/resolv.conf
fi
