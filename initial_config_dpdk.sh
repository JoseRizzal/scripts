#!/bin/bash

###########################  
#   DPDK HyperBashBind    #
###########################

#set -x

HelpMessage(){

    cat <<EOF

    initial_config.sh for dpdk_utils
    -------------

    Usage:
        dpdk_utils init [options]
        ./initial_config.sh [options]

    Start without options:

        Interactive selection of network devices for binding to dpdk driver
        Interactive selection cpus for isolation
        Creation of boot startup script

    Options:

        -h, --help:
            Display help message

        -i, --info, --stat [options]:
            Display devices, numanodes and isolated cpus info
                Options: 
                    --info all
                        Display info both kernel and dpdk NIC devices
                    --info dpdk
                        Display info only dpdk NIC devices
                    --info kernel
                        Display info only kernel NIC devices
                Default mode: all

        -p, --ports:
            Saving devices information into file dpdk_ports.json
        
        -f, --force:
            Attention! Force any changes with devices and cpu isolation

        -d, --devices [options]:
            Select devices in quiet mode (taking slot as parameter, e.g: --devices 0000:00:03.0 0000:00:03.1)
            If --force not specified, will rise error if selected devices have active ssh sessions
                Options:
                    --devices [slot] [slot]...
                        Quiet selection of network devices for binding to dpdk driver
                    --devices pass
                        Pass devices selection (configurate startup script with devices already working with dpdk driver)
                Default mode: none (must have parameter!)

        -c, --cpus [options]:
            Select cpus for isolation in quiet mode (taking cpu numbers as parameters, e.g: --cpus 1 2 3 4)
            If --force not specified, will rise error if selected cpus reserved by OS or not in available range 
                Options:
                    --cpus [cpu] [cpu]...
                        Quiet selection of cpus for isolation
                    --cpus pass
                        Pass cpus selection (configurate startup script with devices and already isolated cpus, or none of them)
                Default mode: none (must have parameter!)

        --clear [slot]:
            Binding devices from dpdk drivers to kernel drivers and up interfaces
            Do not work interactively (don't have selection menu)!
                Options:
                    --clear [slot] [slot]...
                        Unbind selected device(s)
                    --clear all
                        Unbind all dpdk drivers
                        Remove startup script, clear grub config, /etc/rc.local
                Default mode: unbind all dpdk drivers

        --old-init:
            Start old initial config script (initial_config.py)
EOF
}

# print errors in red color
ColorErrorMessage(){ 
    echo -e "\e[31mERROR: ${1}\e[0m" >&2 
}

# print warnings in yellow
ColorWarningMessage(){ echo -e "\e[33mWARNING: ${1}\e[0m"; }

# print note messages in purple
ColorNoteMessage(){ echo -e "\e[35m${1}\e[0m"; }


SetEnvironment(){

    # DESCRIPTION!
    # setting main environment

        # now we're working in multithreads!
        # if we have 0, then change it to 1
        export threads="$(sed 's|0|1|' <<< "$(( $(nproc) / 2 ))")"
                
        # service dir location
        export dpdkDir="$(readlink -f "${0}" | rev | cut -d '/' -f3- | rev)"
        export defaultCfgDir="${dpdkDir}/cfg/default"

        # path to old initial script
        export oldDpdkInitScript="${dpdkDir}/scripts/initial_config.py"

        # the one driver that we actually want to load
        export dpdkDriver="igb_uio"
        # path to dpdk driver
        export dpdkDriverPath="/sys/bus/pci/drivers/igb_uio"


        # sys info paths
        export pciBusPath="/sys/bus/pci/devices"
        export pciSlotsPath="/sys/bus/pci/slots"
        export hardwareInfoPath="/usr/share/hwdata"

        # service dir scripts 
        export pyDpdkBindScript="${dpdkDir}/scripts/dpdk-devbind.py"
        export shOnBootScript="${dpdkDir}/scripts/dpdk_utils_on_boot.sh"
        export bootScript="/etc/rc.d/rc.local"

        # grub set
        export defaultGrubPath="/etc/default/grub"

        # check if we have correct dir
        [[ -d ${dpdkDir}/scripts ]] || {
            echo -e "Error - initial script in wrong directory \nCorrect directory: ${dpdkDir}/scripts" >&2
            exit 1
        }

}

CompatibleModulesList(){

    compatibleModulesList="$(cat <<-EOF | sed 's|#.*||g ; s|  *||g ; s|[,"]||g' | grep -v ^$ | xargs

    # Amazon
    "ena",          # (Elastic Network Adapter)

    # Atomic Rules
    "ark",          # (Arkville Packet Conduit FX0/FX1)

    # Broadcom
    "bnxt",         # (NetXtreme-C, NetXtreme-E, StrataGX)

    # Cavium
    "thunderx",     # (CN88XX, CN83XX, CN81XX, CN80XX)
    "octeontx",     # (CN83XX)
    "liquidio",     # (LiquidIO II CN23XX)
    "bnx2x",        # (QLogic 578xx)
    "qede",     # (QLogic FastLinQ QL4xxxx)

    # Chelsio
    "cxgbe",        # (Terminator 5, Terminator 6)

    # Cisco
    "enic",         # (UCS Virtual Interface Card)

    # Intel
    # Note: The drivers e1000 and e1000e are also called em. The drivers em and igb are sometimes grouped in e1000 family.
    "e1000",            # (82540, 82545, 82546)
    "e1000e",           # (82571, 82572, 82573, 82574, 82583, ICH8, ICH9, ICH10, PCH, PCH2, I217, I218, I219)
    "igb",              # (82575, 82576, 82580, I210, I211, I350, I354, DH89xx)
    "ixgbe",            # (82598, 82599, X520, X540, X550)
    "i40e",             # (X710, XL710, X722)
    "fm10k",            # (FM10420)

    # Marvell
    "mrvl",             # (Marvell Packet Processor v2)

    # Mellanox
    "mlx4",             # (ConnectX-3, ConnectX-3 Pro)
    "mlx5",             # (ConnectX-4, ConnectX-4 Lx, ConnectX-5)

    # Netcope
    "szedata2",         # (NFB-*, NPC-*, NSF-*)

    # Netronome
    "nfp",              # (NFP-4xxx, NFP-6xxx)

    # NXP
    "dpaa",             # (LS102x, LS1043, LS1046)
    "dpaa2",            # (LS1048, LS108x, LS20xx, LX216x)

    # Solarflare
    "sfc_efx",          # (SFN7xxx, SFN8xxx)

    # Paravirtualization
    "avp",              # (Wind River Accelerated Virtual Port)
    "virtio",           # net (QEMU)
    "vmxnet3",          # (VMware ESXi)
    "xenvirt",          # (Xen)

    # Others
    "af_packet",        # (Linux AF_PACKET socket)
    "tap",              # (kernel L2)
    "pcap",             # (file or kernel driver)
    "ring",             # (memory)

    # Attic
    "memnic",           # (Qemu IVSHMEM)
    "vmxnet3",          # usermap (VMware ESXi without uio)
    "oce",              # (Emulex OneConnect OCe14000)

EOF
)"

}

CheckHpetTimer() {

    hpetTimerFile='/sys/devices/system/clocksource/clocksource0/available_clocksource'

    # check hpet timer via avialable timers
    if [[ -f "${hpetTimerFile}" ]] ;  then
        grep -q hpet "${hpetTimerFile}" || warningFlag=1
    fi

    if [[ -n ${warningFlag} ]] ; then
        avialableTimers="$(cat ${hpetTimerFile})"
        kernelConfig="/boot/config-$(uname -r)"

        ColorWarningMessage "\
Cannot found HPET timer into list of avialable timers: 
${avialableTimers}

Because of it, DPDK will use less accurate timers.

You need to:
1. Enable HPET timer into BIOS
2. Enable HPET timer via kernel config ${kernelConfig}: 
    - CONFIG_HPET=y
    - CONFIG_HPET_MMAP=y \
"
    fi
}



SavingDevicesInfo(){
    # DESCRIPTION!
    # export all NIC devices info into json file


    echo "${jsonDevicesList}" > "${dpdkDir}/dpdk_ports.json"

    # maybe only selected devices? not all NICs?
    echo "Saved network devices info in ${dpdkDir}/dpdk_ports.json"

}

ForceCheckArray(){
    # DESCRIPTION!
    # func take array line as parameter, check args in other predefined array line, if match - exit 1

    for x in ${1} ; do
        [[ -n $(grep "${x}" <<< "${forceCheckArray}") ]] && { echo -e "Error - selected items don't match safe initialization (active devices or reserved items) \nYou may suppress it with force parameter: -f|--force" >&2; exit 1; }
    done
}


CreateRawJsonArray(){

    # DESCRIPTION!
    # func take env, populate NIC objects trough loop into json layout (without square brackets)

    export rawJsonArray="{

        \"Slot\": \"${Slot}\",
        \"Slot_str\": \"${Slot_str}\",

        \"Vendor_str\": \"${Vendor_str}\",
        \"Vendor\": \"${Vendor}\",
        \"SVendor_str\": \"${SVendor_str}\",
        \"SVendor\": \"${SVendor}\",

        \"Class_str\": \"${Class_str}\",
        \"Class\": \"${Class}\",

        \"Device_str\": \"${Device_str}\",
        \"Device\": \"${Device}\",

        \"SDevice_str\": \"${SDevice_str}\",
        \"SDevice\": \"${SDevice}\",

        \"Driver_str\": \"${Driver_str}\",
        \"NativeDriver_str\": \"${NativeDriver_str}\",

        \"Module_str\": \"${Module_str}\",
        \"Module\": \"${Module}\",

        \"NUMANode_str\": \"${NUMANode_str}\",
        \"NUMANode\": \"${NUMANode}\",

        \"PhySlot_str\": \"${PhySlot_str}\",
        \"PhySlot\": \"${PhySlot}\",

        \"MAC\": \"${MAC}\",
        \"Interface\": \"${Interface}\",
        \"Speed\": \"${Speed}\",


        \"Ssh_if\": \"${Ssh_if}\",
        \"Active\": \"${Active}\"

    }, "

    echo [${deviceIndex}] ${rawJsonArray}
        #tee -a ${Slot}.slot 1> /dev/null <<< "${rawJsonArray}"
        #echo "[ ${rawJsonArray} ]" | grep -v '^$' # |  python -m json.tool

    
}


PopulateDeviceInfo(){
    # DESCRIPTION!
    # populating env for NICs

    # get index and slot from var
    deviceItem="${1/*---/}"
    deviceIndex="${1/---*/}"


    # base info
        Slot="${deviceItem}"
        Slot_str="${deviceItem#*:}"
        Device="$(cat ${pciBusPath}/${Slot}/device | sed 's|^0x||')"
        Class="0200"
        Class_str="Ethernet Controller"
        NUMANode_str="$(cat ${pciBusPath}/${Slot}/numa_node)"
        NUMANode="${NUMANode_str}"
        SDevice="$(cat ${pciBusPath}/${Slot}/subsystem_device | sed 's|^0x||')"
        Vendor="$(cat ${pciBusPath}/${Slot}/vendor | sed 's|^0x||')"
        SVendor="$(cat ${pciBusPath}/${Slot}/subsystem_vendor | sed 's|^0x||')"
        Driver_str="$(readlink -f ${pciBusPath}/${Slot}/driver | awk -F '/' '{print $NF}')"
        Module="$(readlink -f ${pciBusPath}/${Slot}/driver/module | awk -F '/' '{print $NF}')"

        # info strings
        Vendor_str="$(grep "^${Vendor}" ${hardwareInfoPath}/pci.ids | cut -d ' ' -f2- | sed 's|^ *|| ; s| *$||')"
        SVendor_str="$(grep "^${SVendor}" ${hardwareInfoPath}/pci.ids | cut -d ' ' -f2- | sed 's|^ *|| ; s| *$||')"
        Device_str="$(sed -nE "/^${Vendor}/,/^[0-9]/p" ${hardwareInfoPath}/pci.ids | grep -P "^\t${Device}" | cut -d ' ' -f2- | sed 's|^ *|| ; s| *$||')"
        SDevice_str="$(sed -nE "/^${Vendor}/,/^[0-9]/p" ${hardwareInfoPath}/pci.ids | sed -nE "/^\t${Device}/,/^\t[0-9]/p" | grep -P "\t\t${SVendor} ${SDevice}" | cut -d ' ' -f 3- | sed 's|^ *|| ; s| *$||')"

        # physical slot info
        PhySlot="$(for slot in $(ls ${pciSlotsPath}) ; do [[ -n "$(grep "$(cat ${pciSlotsPath}/${slot}/address)" <<< "${Slot}")" ]] && { echo ${slot}; break; } ; done)"
        PhySlot_str="${PhySlot}"

        # initial info
        NativeDriver_str="$(journalctl -k | grep -oP "(.*${Slot})" | rev | cut -d ' ' -f2 | rev | uniq | sed -n "2p")"
        MAC="$(journalctl -k| grep "${Slot}" | grep -oE '..:..:..:..:..:..' | uniq | xargs)"

        # dynamic keys (either with or without values)
        Interface="$(ls ${pciBusPath}/${Slot}/net 2>/dev/null || :)"

        [[ -n "${Interface}" ]] && dhcpInterfacesList="$(ip -o route | grep -F '169.254' | awk '{print $3}' | sort | uniq)"

        if [[ -n "${dhcpInterfacesList}" ]] ; then
            if [[ -n "$(grep $"Interface" <<< ${dhcpInterfacesList})" ]] ; then
                Ssh_if="True"
                Active="Active"
            fi
        else
            Ssh_if="False"
            Active=""
        fi

        #Speed="$([[ -n "${Interface}" ]] && dmesg | grep -P -m1 "(${Interface}.*NIC Link is Up)" | sed 's|.*NIC Link is Up||' | awk '{print $1$2}')"
        Speed="$([[ -n "${Interface}" ]] && journalctl -k | grep -P -m1 "(${Slot}.*NIC Link is Up)" | sed 's|.*NIC Link is Up||' | awk '{print $1$2}' | tr -d ",;\"'")"
        [[ -z "${Speed}" ]] && Speed="Unknown"

        CreateRawJsonArray
}

GetNetworkDevices(){
        # DESCRIPTION!
        # populating NICs info, create raw json 


        # get network devices array
        for device in $(ls ${pciBusPath}) ; do
                [[ -n "$(grep 0x020000 ${pciBusPath}/${device}/class)" ]] && networkDevicesList="${networkDevicesList} ${device}" ; done
        # check if there is any records, uf not - stop working
        [[ -z "${networkDevicesList}" ]] && { echo "Error - cannot found network devices" >&2; exit 1; }

        # populate array of key:valuedevice

        declare -i index=0
        for item in ${networkDevicesList} ; do idNetworkDevicesList="${idNetworkDevicesList} ${index}---${item}" ; ((index++)) ; done

        # execute in multithreads! in RAM! (sorting via indexes and sed)
        rawJsonArray="$(sed 's| |\n|g' <<< ${idNetworkDevicesList} | xargs -P ${threads} -n 1 -I DEV bash -c 'PopulateDeviceInfo "DEV"' \
                | sort \
                | sed "s|.*{|{\n   |g ; s|,|,\n   |g ; s|}|\n}|g" \
                | grep -v '^   $' \
                | sed -E '$s|,||')"

        [[ -n "${rawJsonArray}" ]] || { echo "Error - cannot create json devices list" >&2; exit 1; }

        export jsonDevicesList="[ ${rawJsonArray} ]"

#       grep -v '^$' <<< "${jsonDevicesList}" |  python -m json.tool
}

InitObj(){

    # DESCRIPTION!
    # func initiate one NIC object at time into env variables

    # working with ranges


    [[ -n "${1}" ]] && num="${1}"

    IFS=';' 
    for x in $( sed -En "${num},/}/p" <<< "${jsonDevicesList}" | sed 's|.*{.*|| ; s|.*}.*||' | grep -v '^$'| awk -F '"' '{print $2"="$4";"}') ; do 
        export "$(grep -v '^$' <<< ${x})"
            done 
    IFS=' '
}



#########################
#    Pass procedure     #
#########################

MainPassdevicesSort(){
    # DESCRIPTION!
    # func for "passdevice" parameter for MainDeviceInitFunc

    if [[ "${Driver_str}" == "${dpdkDriver}" ]] ; then 
        bindingArray="${bindingArray} ${Slot}"
    fi
}


PassProcedure(){
    # DESCRIPTION!
    # 2 scenarious - pass devices; pass cpus
    # creating basic arrays, populate with current active devices; cpus

    case "${1}" in 

        cpus)
            cpuArray="$(grep -oP '(isolcpus.*[^" ])' /etc/default/grub | sed 's|.*=||g ; s|,| |g' | xargs)"
            cpuArray="$(sed 's| |,|g' <<< "${cpuArray}")"
            ;;

        devices)
            objectRangesNums="$(grep -n '{' <<< "${jsonDevicesList}" | cut -d ':' -f1)"
            currentSshSessionsIps="$( ss | grep -oP "([0-9]*.[0-9]*.[0-9]*.[0-9]*:ssh)" | sort | uniq | cut -d ':' -f1)"
            declare -i counter=0

            # get binding array without force
            for num in ${objectRangesNums} ; do
                MainDeviceInitFunc "passdevices"
            done

            # checking if we have any devices in dpdk_mode, if not - error
            [[ -z "${bindingArray}" ]] && { echo -e "Error - not found any devices in dpdk mode, nothing to do \nYou need to initialize devices for dpdk_mode" >&2; exit 1; }

            ;;
    esac
} 


#########################
#     Clearing seq      #
#########################

MainClearingSort(){
    # DESCRIPTION!
    # func for "clearing" parameter for MainDeviceInitFunc

    # if device in dpdk mode - initiate clearing
    if [[ "${Driver_str}" == "${dpdkDriver}" ]] && [[ "${NativeDriver_str}" != "${dpdkDriver}" ]] ; then 
        clearingArray="${clearingArray} ${Slot}"

        # working in quiet mode ; or not
        # creating basic values dict (frankly, line array)
        if [[ -n "${quietClearingArray}" ]] ; then
            #[[ -n "$(grep ${Slot} <<< "${quietClearingArray}")" ]] && clearingDict="${clearingDict};${Slot} ${NativeDriver_str} ${Vendor} ${Device} ${MAC}"
            [[ -n "$(grep ${Slot} <<< "${quietClearingArray}")" ]] && clearingDict="${clearingDict}${clearingDict:+;}${Slot} ${NativeDriver_str} ${Vendor} ${Device} ${MAC}"
        else
            #clearingDict="${clearingDict};${Slot} ${NativeDriver_str} ${Vendor} ${Device} ${MAC}"
            clearingDict="${clearingDict}${clearingDict:+;}${Slot} ${NativeDriver_str} ${Vendor} ${Device} ${MAC}"
        fi
    fi

    # main dictionary for unbinding devices
    #clearingDict="$(sed 's|^;||' <<< ${clearingDict} | xargs)"

}

QuientClearNICs(){
    # DESCRIPTION!
    # quiet checking matching records for params of --clear

    for slot in ${quietClearingArray} ; do
        [[ -z $(grep -P "(${slot}.,)" <<< "${jsonDevicesList}" ) ]] && { echo "Error - cannot found device ${slot} in list of network devices" >&2; exit 1; }
        [[ -z $(grep "${slot}" <<< "${clearingArray}" ) ]] && { echo "Error - cannot found device ${slot} in list of network devices with dpdk driver" >&2; exit 1; }
    done

    # redefine var
    clearingArray="${quietClearingArray}"
}

ClearingSturtupGrub(){
    # DESCRIPTION
    #  --clear all, remove sturtup script, records in grub, /etc/rc.local 

    # delete startup script
    [[ -f "${shOnBootScript}" ]] && rm -rf "${shOnBootScript}"

    # clear /etc/rc/local
    sed -i "s|.*${shOnBootScript}.*||g" "${bootScript}"

    # clear grub
    GrubModificationProcedure "clear"

}


ClearNICs(){
    # DESCRIPTION!
    # top-level clearing seq function

    objectRangesNums="$(grep -n '{' <<< "${jsonDevicesList}" | cut -d ':' -f1)"
    currentSshSessionsIps="$( ss | grep -oP "([0-9]*.[0-9]*.[0-9]*.[0-9]*:ssh)" | sort | uniq | cut -d ':' -f1)"
    declare -i counter=0

    for num in ${objectRangesNums} ; do
        MainDeviceInitFunc "clearing"
    done

    # quiet mode
    [[ -n "${quietClearingArray}" ]] && QuientClearNICs

    # check if we don't have force parametr
    [[ -z "${forceFlag}" ]] && ForceCheckArray "${clearingArray}"

    # clear slots

    IFS=";"

    # basic clearing procedure in loop
    for record in ${clearingDict} ; do

        # Initializing for record as ${Slot} ${NativeDriver_str} ${Vendor} ${Device}
        Slot="$(cut -d ' ' -f1 <<< ${record})"
        NativeDriver_str="$(cut -d ' ' -f2 <<< ${record})"
        Dev_Id="0x$(cut -d ' ' -f3 <<< ${record}) 0x$(cut -d ' ' -f4 <<< ${record})"
        MAC="$(cut -d ' ' -f5 <<< ${record})"

        # tracking massage
        echo -e "\nInitiating clearing procedure for ${Slot} with MAC ${MAC}"

        # unbinding device
        echo -n "Unbinding device from dpdk driver     ..."
        tee "${dpdkDriverPath}/unbind" <<< "${Slot}" > /dev/null || { echo -e "error!" >&2; exit 1; }
        echo "done"

        # new devices override if it is need to
        echo -n "Override device driver     ..."
        if [[ -f "${pciBusPath}/${Slot}/driver_override" ]] ; then
            tee "${pciBusPath}/${Slot}/driver_override" <<< ""  > /dev/null || { echo -e "error!" >&2; exit 1; }
            echo "done"
        else
            tee "${dpdkDriverPath}/new_id" <<< "${Dev_Id}"  > /dev/null || { echo -e "error!" >&2; exit 1; }
            echo "done"
        fi 

        # binding interface to default drv
        echo -n "Binding to kernel driver ${NativeDriver_str}     ..."
        tee "/sys/bus/pci/drivers/${NativeDriver_str}/bind" <<< "${Slot}" > /dev/null || { echo -e "error!" >&2; exit 1; }
        echo "done"

        # get info for ifconfig !!! TO DO for ip
        echo -n "Uplink interface with ifconfig     ..."
        sleep 1
        recNum="$(ifconfig -a | grep -n ${MAC} | cut -d ':' -f1)"
        declare -i i=${recNum}
        while [[ $i -ne 0 ]] ; do 

            # searching for interface name in ifconfig -a (all) output
            interfaceName="$(ifconfig -a | sed -n "${i}p" | grep -oP '(^.*: )' | sed 's|[ :]||g')"
            [[ -n "${interfaceName}" ]] && break
            ((i--))
        done

        # can't have interface - can't have result
        [[ -z "${interfaceName}" ]] && { echo -e "error! \nFault to do uplink for device ${Slot}" >&2; exit 1; }

        # uplink for interface
        ifconfig "${interfaceName}" up || { echo -e "error! \nFault to do uplink for interface ${interfaceName}" >&2; exit 1; }
        echo -e "done \nUplink for interface ${interfaceName} \n"
    done
    IFS=" "

    # if we have "--clear all" , then delete sturtup script, clear /etc/default/grub, /etc/rc.local etc.
    [[ -n "${clearAllFlag}" ]] && ClearingSturtupGrub

}

#############################
#   Get comprehensive info  #
#############################
MainDivicesInfoIteration(){
    # DESCRIPTION!
    # func for "info" parameter for MainDeviceInitFunc

    InfoOutput(){
        # DESCRIPTION!
        # display info (-i, --info, --stat params)

        echo ""

        # header
        echo -e "[${counter}] ${Device_str} ${Device}"
        echo "Slot: ${Slot}"
        echo "Device mode: ${deviceStatus}"

        # If we have ssh
        [[ -n "${sshStatus}" ]] && echo "Ssh connection: Active!"
        [[ -n "${Active}" ]] && echo "Warning! Active 169.254 subnet route!"

        # if numa -1
        [[ -n "${numaStatus}" ]] && echo "Virtual numa status: Active (numa-1)!"

        # if we have interface
        [[ -n "${Interface}" ]] && echo "Interface: ${Interface}"

        # drivers and modules
        echo "Current driver: ${Driver_str}"
        echo "Current module: ${Module}"
        echo "Native driver: ${NativeDriver_str}"

        # additional info
        echo "MAC: ${MAC}"
        echo "Node: ${NUMANode_str}"
        echo "Speed: ${Speed}"


    }

    case "${infoDevicesFlag}" in 
        dpdk)
            [[ "${Driver_str}" == "${dpdkDriver}" ]] && InfoOutput
            ;;
        kernel)
            [[ "${Driver_str}" == "${NativeDriver_str}" ]] && InfoOutput
            ;;
        all)
            InfoOutput
            ;;
        *)
            echo -e "Error - wrong parameter! \nWorking only: -i|--info|--stat [dpdk|kernel|all]" >&2
            exit 1
            ;;
    esac
}


GetInfo(){
    # DESCRIPTION!
    # top-level func for info procedure seq

    # prepare for devices selection
    objectRangesNums="$(grep -n '{' <<< "${jsonDevicesList}" | cut -d ':' -f1)"
    currentSshSessionsIps="$(ss | grep -oP "([0-9]*.[0-9]*.[0-9]*.[0-9]*:ssh)" | sort | uniq | cut -d ':' -f1)"
    declare -i counter=0

    case "${infoDevicesFlag}" in 
        dpdk)
            echo -e "Network Devices (dpdk mode): \n============="
            ;;
        kernel)
            echo -e "Network Devices (kernel mode): \n============="
            ;;
        all)
            echo -e "Network Devices: \n============="
            ;;
        *)
            echo -e "Error - wrong parameter! \nWorking only: -i|--info|--stat [dpdk|kernel|all]" >&2
            exit 1
            ;;
    esac

    # main info iteration 
    for num in ${objectRangesNums} ; do
        MainDeviceInitFunc "info"
    done

    declare -i i=0

    # isolated cpu and numa info
    echo -e "\nCPU and numainfo: \n============="
    echo "Available CPUs: $(cat /sys/devices/system/cpu/present)"

    # show cpus divided by nodes
    cat /sys/devices/system/node/node*/cpulist | while read line ; do echo "  - node${i}: ${line}" ; ((i++)) ; done

    # check isolation
    isolatedCpuArray="$(grep -oP '(isolcpus.*[^" ])' /etc/default/grub | sed 's|.*=||g ; s|,| |g' | xargs)"
    [[ -z "${isolatedCpuArray}" ]] && isolatedCpuArray="none"

    echo "Isolated cpus in ${defaultGrubPath}: ${isolatedCpuArray}"
}

#########################
#    Dirty binding      #
#########################

BindingProcedure() {
    # DESCRIPTION!
    # top-level func for undocumented --dirty-bind parameter

    # full objects initialisation, maybe too redundant, need to check it out
    objectRangesNums=""

    # searching for devices ranges
    for device in ${bindingArray} ; do
        objectRangesNums="${objectRangesNums} $(grep -n "${device}" <<< "${jsonDevicesList}" | cut -d ':' -f1)" ; done

    # init objects, verify compatibility
    for num in ${objectRangesNums} ; do

                # init obj keys
                InitObj

                # rules 
                # Initializing for record as ${Slot} ${NativeDriver_str} ${Vendor} ${Device}
                Slot="${Slot}"
                NativeDriver_str="${NativeDriver_str}"
                Dev_Id="0x${Vendor} 0x${Device}"
                MAC="${MAC}"

                # tracking massage
                echo -e "\nInitiating binding procedure for ${Slot} with MAC ${MAC}"

                # unbinding device
                echo -n "Unbinding device from kernel driver     ..."

                tee "/sys/bus/pci/drivers/${NativeDriver_str}/unbind" <<< "${Slot}" > /dev/null || { echo -e "error!" >&2; exit 1; }
                echo "done"

                # new devices override if it is need to
                echo -n "Override device driver     ..."
                    if [[ -f "${pciBusPath}/${Slot}/driver_override" ]] ; then
                        tee "${pciBusPath}/${Slot}/driver_override" <<< ""  > /dev/null || { echo -e "error!" >&2; exit 1; }
                        echo "done"
                    else
                        tee "${dpdkDriverPath}/new_id" <<< "${Dev_Id}"  > /dev/null || { echo -e "error!" >&2; exit 1; }
                        echo "done"
                    fi

                # binding interface to dpdk drv
                echo -n "Binding to dpdk driver ${dpdkDriver}     ..."
                    #tee "${dpdkDriverPath}/bind" <<< "${Slot}" > /dev/null || { echo -e "error!"; exit 1; }
                    #tee "${dpdkDriverPath}/new_id" <<< "${Dev_Id}"  > /dev/null || { echo -e "error!"; exit 1; }
                    tee "${dpdkDriverPath}/bind" <<< "${Slot}" &> /dev/null || { tee "${dpdkDriverPath}/new_id" <<< "${Dev_Id}"  > /dev/null || { echo -e "error!" >&2; exit 1; }; }
                echo "done"

                # check if binding gone well
                [[ -n "$(ls "${dpdkDriverPath}" | grep "${Slot}")" ]] || { echo -e "Error - cannot bind dpdk driver ${dpdkDriver} to ${Slot}" >&2; exit 1; }
                echo "Successfully binded dpdk driver"
    done
}

#########################
#   Devices Selection   #
#########################

MainDeviceInitFunc(){

    # DESCRIPTION!
    # main func. modificate env with initiated vars

    MessageForm(){
        # DESCRIPTION!
        # massage for interactive devices selection

        message="
                        [${counter}]
                        ${deviceStatus}
                        ${sshStatus}
                        ${numaStatus}
                        ${Slot}
                        \'${Device_str} ${Device}\'
                        ${interfaceStatus}
                        drv=${Driver_str}
                        native_drv=${NativeDriver_str}
                        unused=${Module}
                        speed=${Speed}
                        mac=${MAC}
                        node=${NUMANode_str}
                        ${Active}
                        ${ParallelForceCheckStatus}
                "
                echo ${message} | xargs
    }

                # init obj keys
            if [[ -n "${2}" ]] ; then
                # for checking force check in mulrtithreads
                parallelFlag="enable"
                #num="$(cut -d '-' -f2 <<< ${2})"
                num="${2/*-/}"
                #counter="$(cut -d '-' -f1 <<< ${2})"
                counter="${2/-*/}"
            fi
        

                InitObj


                # rules 
                # if we have interface and ssh-sessions
                if [[ -n "${Interface}" ]] ; then
                    interfaceStatus="if=${Interface}"

                    # checking if interface has active ssh sessions
                    interfaceIp="$(ip address show "${Interface}" | grep -P "(inet.*${Interface})" | sed 's|inet \(.*\)/.*|\1| ; s|  *||')"
                    [[ -n "${interfaceIp}" ]] && [[ -n "$(grep ${interfaceIp} <<< "${currentSshSessionsIps}")" ]] && sshStatus="(ssh_session!)"

                    # force check array
                    [[ -n "${sshStatus}" ]] && forceCheckArray="${forceCheckArray} ${Slot}"

                fi

                # force for active status
                [[ -n "${Active}" ]] && forceCheckArray="${forceCheckArray} ${Slot}"

                # if we already have devices with dpdk drivers

                if [[ "${Driver_str}" != "${dpdkDriver}" ]] && [[ -n "${interfaceStatus}" ]] ; then
                        deviceStatus="(kernel_mode)"
                elif [[ "${Driver_str}" == "${dpdkDriver}" ]] ; then
                        deviceStatus="(dpdk_mode)"
                else
                        deviceStatus="(unknow_mode)"
                fi

                # if we are with vm node (-1)
                if [[ "${NUMANode_str}" == "-1" ]] ; then
                    numaStatus="(vm_numa-1!)"
                    # adding to restricted array
                    forceCheckArray="${forceCheckArray} ${Slot}"
                fi  

                # write special status for parallel implementation
                [[ -n "${parallelFlag}" ]] && ParallelForceCheckStatus="ParallelForceCheckStatus=$(sed s'| |\n|g' <<< ${forceCheckArray} | sort -u)"

                # different sorting and inits for functions
                case "${1}" in 
                    interactive)
                        MessageForm
                        ;;
                    clearing)
                        MainClearingSort
                        ;;
                    passdevices)
                        MainPassdevicesSort
                        ;;
                    info)
                        MainDivicesInfoIteration
                        ;;
                esac

                ((counter++))
                unset deviceStatus interfaceStatus sshStatus
}

QuietDevicesSelection(){
    # DESCRIPTION!
    # take devices array from -d parameter

    for slot in ${quietBindingArray} ; do 
        [[ -z "$(grep -E "(${slot}.,)" <<< "${jsonDevicesList}")" ]] && { echo "Error - cannot found ${slot} in network devices" >&2; exit 1; } ; done

    objectRangesNums="$(grep -n '{' <<< "${jsonDevicesList}" | cut -d ':' -f1)"

    currentSshSessionsIps="$(ss | grep -oP "([0-9]*.[0-9]*.[0-9]*.[0-9]*:ssh)" | sort | uniq | cut -d ':' -f1)"
    declare -i counter=0

    for num in ${objectRangesNums} ; do
        MainDeviceInitFunc
    done

    bindingArray="${quietBindingArray}"

    # check if we don't have force parametr
    [[ -z "${forceFlag}" ]] && ForceCheckArray "${bindingArray}"
}




DevicesSelecton(){
    # DESCRIPTION!
    # top-level func for devices selection

    # working in pass mode
    [[ -n "${passDevicesFlag}" ]] && { PassProcedure "devices"; return 0; }

    # working in quiet mode
    [[ -n "${quietBindingArray}" ]] && { QuietDevicesSelection; return 0; }

    # tracking message  
    echo -e "Network Devices: \n============="

    objectRangesNums="$(grep -n '{' <<< "${jsonDevicesList}" | cut -d ':' -f1)"

    export currentSshSessionsIps="$( ss | grep -oP "([0-9]*.[0-9]*.[0-9]*.[0-9]*:ssh)" | sort | uniq | cut -d ':' -f1)"
    declare -i counter=0


    for num in ${objectRangesNums} ; do
        tempArray="${tempArray} $counter-$num"
        ((counter++))
    done


    objectRangesNums="${tempArray}"

    # execute in multithreads! 
    displayDevices="$(sed 's| |\n|g' <<< ${objectRangesNums}  | xargs -P ${threads} -n 1 -I num bash -c 'MainDeviceInitFunc "interactive" "num"' | sort)"

    # parallel force check sync
    forceCheckArray="$(grep -oE "ParallelForceCheckStatus.* ?" <<< "${displayDevices}" | cut -d '=' -f2 | xargs)"
    # display devices
    sed -E "s|ParallelForceCheckStatus=.* ?||g" <<< "${displayDevices}"

    # interactive selection 
    declare -i counter=0
    for item in $(grep -o '0000:..:....' <<< "${jsonDevicesList}" | xargs) ; do selectionItems="${counter}-${item} ${selectionItems}" ; ((counter++)) ; done

    echo -n "Enter devices to use with DPDK (for example 0,1,2,3): "

    while [[ -z "${bindingArray}" ]] ; do
        errorMessage="Wrong input! Please prompt correct numbers"

        read -p '' userChoise
        userChoise="$(sed 's|,| |g ; s/[^0-9 ]*//g' <<< "${userChoise}")"
        [[ -z "${userChoise}" ]] && { echo "${errorMessage}"; continue; }

        for val in ${userChoise} ; do
            tempSelect="$(grep -oP "(${val}-0000:..:....)" <<< $selectionItems | cut -d '-' -f2)"
            [[ -z "${tempSelect}" ]] && { echo "${errorMessage}"; unset bindingArray; break; }
            bindingArray="${tempSelect} ${bindingArray}"
        done
    done

    # check if we don't have force parametr
    [[ -z "${forceFlag}" ]] && ForceCheckArray "${bindingArray}"

}


#########################
#     CPU Selection     #
#########################

MainCpusInitFunc(){
    # DESCRIPTION!
    # main func for cpu selection (working in loop)

        errorMessage="Wrong input! Incorrect cpu numbers (reserved or not in available range)"

        # parse sequence
        userChoise="$(sed 's|,| |g' <<< "${userChoise}")"

        # take only integers, commas and dashes
        [[ -n "$(sed -E "s|[0-9|-]||g ; s|  *||"  <<< "${userChoise}")" ]] && { echo "${errorMessage}"; return 1; }

        # dealing with ranges
        for range in $(grep -oP '([0-9]*-[0-9]*)' <<< ${userChoise} | xargs) ; do
            range="$(seq -s ' ' $(sed 's|-| |' <<< ${range}))"
            rangeArray="${range} ${rangeArray}"
        done

        #userChoise="$(echo ${rangeArray} $(sed -E 's|[0-9]*-[0-9]*||g' <<< ${userChoise}) | grep -o . | sort | uniq | xargs)"
        userChoise="$(echo ${rangeArray} $(sed -E 's|[0-9]*-[0-9]*||g' <<< ${userChoise}) | xargs | sed 's| |\n|' | sort -u | xargs)"

        [[ -z "${userChoise}" ]] && { echo "${errorMessage}"; return 1; }
        [[ -n "$(sed -E "s|[0-9]||g ; s|  *||"  <<< "${userChoise}")" ]] && { echo "${errorMessage}"; return 1; }

        # checking if we have selected cpus in OS
        for cpu in ${userChoise} ; do 
            [[ -z "$(grep ",${cpu}," <<< "$(echo ",$(sed 's| |,|g' <<< "${availableCpu}"),")")" ]] && { echo "${errorMessage}"; unset cpuArrayFlag; break; }
            #[[ -z "$(grep ${cpu} <<< "${availableCpu}")" ]] && { echo "${errorMessage}"; unset cpuArrayFlag; break; }
            cpuArrayFlag="enable"
        done

        [[ -n "${cpuArrayFlag}" ]] && cpuArray="$(sed 's| |,|g' <<< "${userChoise}")"
}

QuietCpuSelection(){
    # DESCRIPTION!
    # quiet checking cpus in line array

    userChoise="${quietCpuArray}"
    MainCpusInitFunc || exit 1
}


CpuSelection(){
    # DESCRIPTION!
    # top-level func for -c param

    # working in pass mode
    [[ -n "${passCpuFlag}" ]] && { PassProcedure "cpus"; return 0; }

    # get all available cpus
    availableCpu="$(seq -s ' ' $(sed 's|-| |' /sys/devices/system/cpu/present))"
    # pass if have only one cpu
    [[ -z "${availableCpu}" ]] && { echo "Found only one cpu, passing cpu isolation"; return 0; } 

    # take of one cpu from each numanode to restrict isolation and pass it to OS
        # NOTE: "cut -d ',' -f1" fixes DELL servers issue
    restrictedCpus="$(cat /sys/devices/system/node/node*/cpulist | cut -d '-' -f1 | cut -d ',' -f1 | xargs)"

    # working without force parameter
    if [[ -z "${forceFlag}" ]] ; then

        # get rid of restricted cpus in available cpus
        for cpu in ${availableCpu} ; do
            declare -i int=${cpu}
            for item in ${restrictedCpus} ; do
                declare -i rInt=${item}
                [[ ${int} -eq ${rInt} ]] && getRid="enable"
            done
            [[ -z "${getRid}" ]] && tempAvailableCpu="${tempAvailableCpu} ${int}"
            unset getRid
        done
        availableCpu="${tempAvailableCpu}"
    fi

    # check if we working on in quiet mode
    [[ -n "${quietCpuArray}" ]] && { QuietCpuSelection; return 0; }

    echo "Available CPUs: ${availableCpu}"
    [[ -z "${forceFlag}" ]] && echo "CPU, reserved for OS: ${restrictedCpus}"
    [[ -z "${forceFlag}" ]] && echo "Warning! You cannot isolate reserved cpus for DPDK!"
    echo -n "Enter cpus to use exclusively with DPDK, started (for example 1,2,3 or 1-3 or 2-4,5): "

    while [[ -z "${cpuArray}" ]] ; do
        unset rangeArray
        read -p '' userChoise
        MainCpusInitFunc || continue
    done
}

#################################
#    Verification and boot      #
#################################

NetworkDevicesVerification(){
    # DESCRIPTION!
    # check our driver in list of compatible modules
    
    # create compatible modules list
    CompatibleModulesList

    # full objects initialisation, maybe too redundant, need to check it out
    objectRangesNums=""

    # searching for devices ranges
    for device in ${bindingArray} ; do
        objectRangesNums="${objectRangesNums} $(grep -n "${device}" <<< "${jsonDevicesList}" | cut -d ':' -f1)" ; done

    # init objects, verify compatibility
    for num in ${objectRangesNums} ; do

                # init obj keys
                InitObj

                # rules 
                [[ -n "$(grep ${NativeDriver_str} <<< ${compatibleModulesList})" ]] || { echo "Error, cannot find native module ${NativeDriver_str} for NIC ${device} in compatible modules list"; exit 1; } ; done
}

CreateStatrupEntryPoint(){
    # DESCRIPTION!
    # func for creating dpdk_utils_on_boot.sh file, then pass script name to /etc/rc.local

    # full objects initialisation, maybe too redundant, need to check it out
    objectRangesNums=""

    # searching for devices ranges
    for device in ${bindingArray} ; do
        objectRangesNums="${objectRangesNums} $(grep -n "${device}" <<< "${jsonDevicesList}" | cut -d ':' -f1)" ; done

    # init objects, get arrays for drivers binding
    for num in ${objectRangesNums} ; do

                # init obj keys
                InitObj

                # create nodes array
                activeNodesArray="${activeNodesArray} ${NUMANode_str}" 

    done

    # sorting to uniq
    activeNodesArray="$(sort -u <<< "$(sed 's| |\n|g' <<< ${activeNodesArray})" | xargs)"
    # get rid from -1 numanodes
    activeNodesArray="$(sed 's|-1||g' <<< "${activeNodesArray}")"

    # searching for passive nodes
    allNodes="$(ls /sys/devices/system/node | grep node | grep -oE '[0-9]+')"
    for i in ${activeNodesArray} 0 ; do allNodes="${allNodes/${i}/}" ; done
    passiveNodes="$(xargs <<< ${allNodes})"


    # total hugepages
    declare -i tempTotalHugepages=0

    # checking if proc has support for hugepages
    [[ -n "$(grep "pdpe1gb" /proc/cpuinfo)" ]] && { hugepagesSize="1048576kB"; declare -i nrHugepages="2"; hugepagesFlag="enable"; }
    [[ -z "${hugepagesSize}" ]] && { hugepagesSize="2048kB"; declare -i nrHugepages="700"; }

    for node in ${activeNodesArray} ; do 
        setHugepagesLines="${setHugepagesLines}${setHugepagesLines+ ;} echo ${nrHugepages} > /sys/devices/system/node/node${node}/hugepages/hugepages-${hugepagesSize}/nr_hugepages" ; tempTotalHugepages=$((${tempTotalHugepages}+${nrHugepages})) ; done

        # TO DO? hugepages total?

    if [[ -z "$(grep '0' <<< ${activeNodesArray})" ]] ; then
        if [[ -n "${hugepagesFlag}" ]] ; then
            declare -i nrHugepages="1"
        else
            declare -i nrHugepages="10"
        fi
        setHugepagesLines="${setHugepagesLines} ; echo ${nrHugepages} > /sys/devices/system/node/node0/hugepages/hugepages-${hugepagesSize}/nr_hugepages" 
        tempTotalHugepages=$((${tempTotalHugepages}+${nrHugepages}))
    fi

    # dealing with passive nodes
    if [[ -n "${passiveNodes}" ]] ; then
        for node in ${passiveNodes} ; do
            setHugepagesLines="${setHugepagesLines}${setHugepagesLines+ ;} echo 0 > /sys/devices/system/node/node${node}/hugepages/hugepages-${hugepagesSize}/nr_hugepages"
        done
    fi

    [[ ${tempTotalHugepages} -eq 0 ]] && { echo "Error - cannot set hugepages, current total number is still 0" >&2; exit 1; }

    # populate shell EP script
    # shebang
    echo -e '#!/bin/bash \n' > "${shOnBootScript}"
    # hugepages binding
    IFS=';' 
    echo -e "\n # allocate huge pages" >> "${shOnBootScript}"
    for line in ${setHugepagesLines} ; do
        echo "${line}" >> "${shOnBootScript}" ; done
    IFS=' '
    # dpdk devbind
    echo -e "\n # bind dpdk driver to selected network devices \n${pyDpdkBindScript} -b ${dpdkDriver} ${bindingArray}" >> "${shOnBootScript}"

    # check if startup script is executable
    [[ ! -x "${shOnBootScript}" ]] && chmod +x "${shOnBootScript}"

    # enable startup script
    chmod +x "${bootScript}"
    [[ -z $(grep "/bin/bash ${shOnBootScript}" "${bootScript}") ]] && echo "/bin/bash ${shOnBootScript}" >> "${bootScript}" 

    echo "Startup script has enabled"
    totalHugepages="${tempTotalHugepages}"
}



GrubModificationProcedure(){
    # DESCRIPTION!
    # modificate /etc/default/grub file

    # take param if we just clear grub
    [[ "${1}" == "clear" ]] && clearGrub="enable"

    # get num of cmd line
    cmdLineIndex="$(grep -n "GRUB_CMDLINE_LINUX=" ${defaultGrubPath} | cut -d ':' -f1)"

    # appender for hugepages 1Gb
    [[ -n "${hugepagesFlag}" ]] && stringAppender="default_hugepagesz=1G hugepagesz=1G"

    # hugepages counter
    hugepagesAppender="hugepages=${totalHugepages}"

    # isolcpus string
    [[ -n "${cpuArray}" ]] && isolcpusAppender="isolcpus=${cpuArray}"

    # full appender
    stringToAppend="${stringAppender} ${hugepagesAppender} ${isolcpusAppender}"

    # if we clearing grub, unset string appender
    [[ -n "${clearGrub}" ]] && unset stringToAppend

    # looking for old initialising credits
    grubParamLine="$(grep "^GRUB_CMDLINE_LINUX=" ${defaultGrubPath} | cut -d '"' -f2)"

    # if we have empty string
    if [[ -z "${grubParamLine}" ]] ; then
        [[ -n "${stringToAppend}" ]] && tee -a ${defaultGrubPath} <<< "GRUB_CMDLINE_LINUX=\"$(echo ${stringToAppend})\""

    # if we have param line
    else
        for record in ${grubParamLine} ; do 
            [[ -z "$(grep -P '(hugepages|isolcpus)' <<< "${record}")" ]] && cleanedParamLine="${cleanedParamLine} ${record}" ; done

        sed -i "s|^GRUB_CMDLINE_LINUX=.*|GRUB_CMDLINE_LINUX=\"$(echo ${cleanedParamLine})\"|" "${defaultGrubPath}"

        # change grub
        sed -i "${cmdLineIndex}s|.$| ${stringToAppend}\"|" "${defaultGrubPath}" || { echo "Error - cannot updated ${defaultGrubPath}" >&2; exit 1; }
    fi

    echo "Updated ${defaultGrubPath}"

    # udate grub config
    grub2-mkconfig -o /etc/grub2.cfg

}

GetToReboot(){
    # DESCRIPTION!
    # if don't have --pass parameter - echoing "please reboot" message

    if [[ -z "${passDevicesFlag}" ]] && [[ -z "${passCpuFlag}" ]] ; then
        echo "All procedures are completed, please reboot to take effect" 
    fi
}


#################
#   START CODE  #
#################

# export functions for isolated multithreaded tasks
exportFuncArray="
    PopulateDeviceInfo
    CreateRawJsonArray
    ForceCheckArray
    InitObj
    MainPassdevicesSort
    PassProcedure
    MainClearingSort
    QuientClearNICs
    ClearingSturtupGrub
    ClearNICs
    MainDivicesInfoIteration
    GetInfo
    BindingProcedure
    MainDeviceInitFunc
    QuietDevicesSelection
    DevicesSelecton
    NetworkDevicesVerification

"
for foo in ${exportFuncArray} ; do export -f ${foo} ; done


# checking parameters

if [[ -n "$@" ]] ; then

    argsArray="$@"

    # searching for combined arguments eg. -abdcd etc.
    combineArgs="$(printf "%s \n" ${argsArray} | grep -oP '^-[A-z]*' | grep -v '^-$')"
    [[ -n "${combineArgs}" ]] && {
        for x in ${combineArgs} ; do 
            splitedLine="$(grep -o . <<< ${x} | sed 's|^|-|g ; s|-[- $]||g' | xargs)"
            argsArray="${argsArray/${x}/${splitedLine}}"
        done
    }

    argsArray="$(sed 's|  *| |g; s| |=|g ; s|=-| -|g' <<< ${argsArray})"

    for position in ${argsArray} ; do

        param="${position/=*/}"
        value=$(tr '="' ' ' <<< ${position#*=})

        case "${param}" in

            --old-init)
                procedureSeq="oldinit"
                ;;

            -d|--devices)
                [[ -z "${value}" ]] && { echo 'Error - you need to specify slots for -d|--devices parameter, e.g: --devices="0000:00:03.0 0000:00:03.1"' >&2; exit 1; }
                quietBindingArray="${value}"
                [[ "${value}" == "pass" ]] && passDevicesFlag="enable"
                ;;

            -c|--cpus)
                [[ -z "${value}" ]] && { echo 'Error - you need to specify cpus for -c|--cpus, e.g: --cpus="1,2,3,4"' >&2; exit 1; }
                quietCpuArray="${value}"
                [[ "${value}" == "pass" ]] && passCpuFlag="enable"
                ;;

            --clear)
                procedureSeq="clearing"
                [[ "${value}" != "${param}" ]] && quietClearingArray="${value}"
                [[ "${value}" == "all" ]] && { unset quietClearingArray; clearAllFlag="enabled"; }
                ;;

            -f|--force)
                forceFlag="enable"
                ;;

            # this is for undocumented option! pass NICs and CPUs selection, rewrite scripts
            --pass|--dry)
                passCpuFlag="enable"
                passDevicesFlag="enable"
                ;;

            -i|--info|--stat)
                procedureSeq="info"
                [[ "${value}" == "${param}" ]] && infoDevicesFlag="all"
                [[ "${value}" == "all" ]] && infoDevicesFlag="all"
                [[ "${value}" == "dpdk" ]] && infoDevicesFlag="dpdk"
                [[ "${value}" == "kernel" ]] && infoDevicesFlag="kernel"
                [[ -z "${infoDevicesFlag}" ]] && { echo -e "Error - wrong parameter! \nWorking only: -i|--info|--stat [dpdk|kernel|all]" >&2; exit 1; }
                ;;

            -h|--help)
                HelpMessage
                exit 0
                ;;

            # this is for undocumented option! fast binding to dpdk driver
            --dirty-bind)
                procedureSeq="binding"
                [[ "${value}" != "${param}" ]] && quietBindingArray="${value}"
                ;;

            -p|--ports)
                procedureSeq="portsinfo"
                ;;

            --)
                [[ ${param} == "${1}" ]] && {
                    echo 'Error - not enough parameters!' >&2
                    HelpMessage
                    exit 1
                }
                break
                ;;

            *)
                echo 'Error - wrong parameter '${param}'!' >&2
                HelpMessage
                exit 1
                ;;
        esac
    done
fi


SetEnvironment
CheckHpetTimer

case "${procedureSeq}" in

    oldinit)
        # old python script
        ${oldDpdkInitScript}
        ;;

    clearing)
        GetNetworkDevices
        ClearNICs
        ;;
    info)
        GetNetworkDevices
        GetInfo     
        ;;
    binding)
        GetNetworkDevices
        DevicesSelecton
        NetworkDevicesVerification
        BindingProcedure
        ;;      
    portsinfo)
        GetNetworkDevices
        SavingDevicesInfo
        ;;
    *)
        GetNetworkDevices
        DevicesSelecton
        CpuSelection
        NetworkDevicesVerification
        SavingDevicesInfo
        CreateStatrupEntryPoint
        GrubModificationProcedure
        GetToReboot
        ;;
esac











