#!/bin/bash

set -euo pipefail
date
#env
INPUT="./vms/msvm.csv"

echo "Please enter vCenter connection details:"

read -p "vCenter_URL (e.g. https://vcenter.example.local): " GOVC_URL
read -p "vCenter_USERNAME (e.g. administrator@vsphere.local): " GOVC_USERNAME
read -s -p "vCenter_PASSWORD: " GOVC_PASSWORD
echo ""
read -p "vCenter_DATACENTER (e.g. TR_DC): " DCENTER
read -p "vCenter_CLUSTER (e.g. TR_CLS): " DCLUSTER
read -p "vCenter_DATASTORE (e.g. TR-DS01): " DSTORE
read -p "vCenter Template Name (e.g. RH9_tmp, UBNT2204_tmp, W2022_tmp): " TEMPLATE

export GOVC_URL GOVC_USERNAME GOVC_PASSWORD
export GOVC_INSECURE=1
export GOVC_DATACENTER=$DCENTER

#echo $GOVC_URL $GOVC_USERNAME $GOVC_PASSWORD

#####################################################################

echo "Testing vCenter connection..."
if ! govc about > /dev/null 2>&1; then
  echo "X:Error: vCenter connection failed! Please check your credentials."
  exit 1
else
  echo "●:OK: Connection successful!"
fi

#####################################################################

while IFS=';' read -r folder vmname hostname osdisk disk1 disk2 disk3 cpu memory vlan ip netmask gw dns1 dns2 domain vmenv vmteam; do
  if [[ "$folder" == "folder" ]]; then
    continue
  fi

  echo "=========================================="
  echo "Creating folder: $folder"
  echo "Started: $(date '+%Y-%m-%d %H:%M:%S')"
  echo "=========================================="

  if ! govc folder.info "/$DCENTER/vm/$folder" >/dev/null 2>&1; then
      govc folder.create "/$DCENTER/vm/$folder"
      echo "Folder Created: $folder"
  else
      echo -e "Folder already exist!"
  fi

  echo "=========================================="
  echo "Cloning VM: $vmname from template: $TEMPLATE"
  echo "=========================================="
  
  START_TIME=$(date +%s)
   govc vm.clone -vm="$TEMPLATE" -ds=$DSTORE -pool="$DCLUSTER/Resources" -folder=$folder -net=$vlan -on=false $vmname
 
  echo "Adding Network to VM: $vmname $vlan"
  
  govc vm.network.add -vm "$vmname" -net "$vlan" -net.adapter vmxnet3
  govc device.connect -vm $vmname ethernet-0
  
  echo "Setting CPU and Memory for $vmname"
  
  memory_mb=$((memory * 1024))
  govc vm.change -vm "$vmname" -c="$cpu" -m="$memory_mb"
  
  # Add disk2 if specified
  if [[ -n "$disk2" && "$disk2" != "0" ]]; then
    echo "Adding Disk2: ${disk2}GB to $vmname"
    govc vm.disk.create -vm "$vmname" -name "$vmname/disk2.vmdk" -size "${disk2}G" -ds "$DSTORE"
  fi

  # Add disk3 if specified
  if [[ -n "$disk3" && "$disk3" != "0" ]]; then
    echo "Adding Disk3: ${disk3}GB to $vmname"
    govc vm.disk.create -vm "$vmname" -name "$vmname/disk3.vmdk" -size "${disk3}G" -ds "$DSTORE"
  fi  


  echo "Customizing VM $vmname (hostname, IP, DNS)"
  govc vm.customize \
    -vm "$vmname" \
    -name "$vmname" \
    -org "$vmname" \
    -type Windows \
    -name "$hostname" \
    -ip "$ip" \
    -netmask "$netmask" \
    -gateway "$gw" \
    -dns-server "$dns1,$dns2" \
    -username "administrator"
    #-auto-login 1
  
  echo "Adding Annotations"
  govc vm.change -vm "$vmname" -annotation $'Deployed via govc on '"$(date +%F)"$'\nEnv: '"$vmenv"$'\nTeam: '"$vmteam"

  echo "Powering on VM: $vmname"
  govc vm.power -on "$vmname"

  echo "Waiting for IP address..."
  IP_START=$(date +%s)
  govc vm.ip -wait 5m "$vmname"
  IP_END=$(date +%s)
  IP_DURATION=$((IP_END - IP_START))
  echo "IP assigned in $IP_DURATION seconds"
 
  END_TIME=$(date +%s)
  TOTAL_DURATION=$((END_TIME - START_TIME))
  MINUTES=$((TOTAL_DURATION / 60))
  SECONDS=$((TOTAL_DURATION % 60))
  echo "----------------------------------------"

  date

echo ""
echo "=========================================="
echo "$vmname DEPLOYMENT SUMMARY"
echo "=========================================="
echo "Folder         : $folder"
echo "VM Name        : $vmname"
echo "Hostname       : $hostname"
echo "IP Address     : $ip"
echo "Netmask        : $netmask"
echo "Gateway        : $gw"
echo "Dns1, Dns2     : $dns1 $dns2"
echo "Vlan           : $vlan"
echo "Cpu            : $cpu"
echo "Memory         : $memory"
echo "OS Disk        : $disk1"
echo "Disk 2         : $disk2"
echo "Disk 3         : $disk3"
echo "Environment    : $vmenv"
echo "Team           : $vmteam"
echo "----------------------------------------"
echo "Task Complete  : ${MINUTES}m ${SECONDS}s"
echo "=========================================="

done < "$INPUT"
govc session.logout
