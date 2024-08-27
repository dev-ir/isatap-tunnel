#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
plain='\033[0m'
NC='\033[0m' # No Color

# check root
[[ $EUID -ne 0 ]] && echo -e "${RED}Fatal error: ${plain} Please run this script with root privilege \n " && exit 1


DVHOST_CLOUD_install_jq() {
    if ! command -v jq &> /dev/null; then
        if command -v apt-get &> /dev/null; then
            echo -e "${RED}jq is not installed. Installing...${NC}"
            sleep 1
            sudo apt-get update
            sudo apt-get install -y jq
        else
            echo -e "${RED}Error: Unsupported package manager. Please install jq manually.${NC}\n"
            read -p "Press any key to continue..."
            exit 1
        fi
    fi
}

DVHOST_CLOUD_require_command(){
    apt install python3-pip -y
    DVHOST_CLOUD_install_jq
    if ! command -v pv &> /dev/null; then
        echo "pv could not be found, installing it..."
        sudo apt update
        sudo apt install -y pv
    fi
}

DVHOST_CLOUD_menu(){
    clear
    SERVER_IP=$(hostname -I | awk '{print $1}')
    SERVER_COUNTRY=$(curl -sS "http://ip-api.com/json/$SERVER_IP" | jq -r '.country')
    SERVER_ISP=$(curl -sS "http://ip-api.com/json/$SERVER_IP" | jq -r '.isp')

    echo "+-----------------------------------------------------------------------+"                                                                                                
    echo "|  _____    ______         _        _________        _        _______   |"
    echo "| |_   _| .' ____ \       / \      |  _   _  |      / \      |_   __ \  |"
    echo "|   | |   | (___ \_|     / _ \     |_/ | | \_|     / _ \       | |__) | |"
    echo "|   | |    _.____ .     / ___ \        | |        / ___ \      |  ___/  |"
    echo "|  _| |_  | \____) |  _/ /   \ \_     _| |_     _/ /   \ \_   _| |_     |"
    echo "| |_____|  \______.' |____| |____|   |_____|   |____| |____| |_____|    |"
    echo "+-----------------------------------------------------------------------+"                                                                                                
    echo -e "| Telegram Channel : ${GREEN}@DVHOST_CLOUD ${NC}|YouTube : ${RED}youtube.com/@dvhost_cloud${NC} |"
    echo "+-----------------------------------------------------------------------+"                                                                                                
    echo -e "|${GREEN}Server Country    |${NC} $SERVER_COUNTRY"
    echo -e "|${GREEN}Server IP         |${NC} $SERVER_IP"
    echo -e "|${GREEN}Server ISP        |${NC} $SERVER_ISP"
    echo "+-----------------------------------------------------------------------+"                                                                                                
    echo -e "|${YELLOW}Please choose an option:${NC}"
    echo "+-----------------------------------------------------------------------+"                                                                                                
    echo -e $1
    echo "+-----------------------------------------------------------------------+"                                                                                                
    echo -e "\033[0m"
}

DVHOST_CLOUD_MAIN(){
    clear
    DVHOST_CLOUD_menu "| 1  - Install Localv6 \n| 2  - Tunnel Plus \n| 3  - Status \n| 0  - Exit"
    read -p "Enter your choice: " choice
    
    case $choice in
        1)
            DVHOST_CLOUD_GET_LOCAL_IP
        ;;
        2)
            DVHOST_CLOUD_TUNNEL
        ;;
        3)
            DVHOST_CLOUD_check_status
        ;;
        0)
            echo -e "${GREEN}Exiting program...${NC}"
            exit 0
        ;;
        *)
            echo "Invalid choice. Please try again."
            read -p "Press any key to continue..."
        ;;
    esac
}

DVHOST_CLOUD_TUNNEL(){
    DVHOST_CLOUD_menu "| 1  - Setup Tunnel  \n| 2  - Remove Tunnel \n| 0  - Exit"
    read -p "Enter your choice: " choice

    case $choice in
        1)
            DVHOST_CLOUD_setup_tunnel_and_forward
        ;;
        2)
            DVHOST_CLOUD_cleanup_socat_tunnel
        ;;
        0)
            echo -e "${GREEN}Exiting program...${NC}"
            exit 0
        ;;
        *)
            echo "Invalid choice. Please try again."
            read -p "Press any key to continue..."
        ;;
    esac
}

DVHOST_CLOUD_check_status() {
    if ip link show isatap1 &> /dev/null; then
        echo -e "\e[32mTunnel is UP.\e[0m"
    else
        echo -e "\e[31mTunnel is DOWN.\e[0m"
    fi
}

DVHOST_CLOUD_GET_LOCAL_IP(){
    clear
    DVHOST_CLOUD_menu "| 1  - IRAN \n| 2  - KHAREJ \n| 0  - Exit"
    read -p "Enter your choice: " choice
    
    case $choice in
        1)
            read -p "Enter the IPv4 address of Server 1 (This server): " server1_ip
            read -p "Enter the IPv4 address of Server 2 (Remote server): " server2_ip
            DVHOST_CLOUD_create_tunnel_and_ping $server1_ip $server2_ip
        ;;
        2)
            read -p "Enter the IPv4 address of Server 2 (This server): " server2_ip
            read -p "Enter the IPv4 address of Server 1 (Remote server): " server1_ip
            DVHOST_CLOUD_create_tunnel_and_ping $server2_ip $server1_ip
        ;;
        0)
            echo -e "${GREEN}Exiting program...${NC}"
            exit 0
        ;;
        *)
            echo "Invalid choice. Please try again."
            read -p "Press any key to continue..."
        ;;
    esac
}

DVHOST_CLOUD_create_tunnel_and_ping() {
    local this_server_ip=$1
    local remote_server_ip=$2
    local this_server_hex=$(DVHOST_CLOUD_ip_to_hex $this_server_ip)
    local remote_server_hex=$(DVHOST_CLOUD_ip_to_hex $remote_server_ip)
    local this_server_ipv6="fe80::200:5efe:$this_server_hex"
    local remote_server_ipv6="fe80::200:5efe:$remote_server_hex"

    sudo ip tunnel add isatap1 mode isatap local $this_server_ip
    sudo ip link set isatap1 up
    sudo ip -6 addr add $this_server_ipv6/64 dev isatap1
    sudo sysctl -w net.ipv6.conf.all.forwarding=1
    echo "Tunnel created successfully for $this_server_ip."

    echo "=========================================="
    echo -e "| IPv6 address of the remote server: ${RED}$remote_server_ipv6%isatap1${NC} |"
    echo "=========================================="

    echo "Pinging the remote server ($remote_server_ipv6)..."
    ping6 -I isatap1 $remote_server_ipv6 -c 4

    echo "To manually ping the remote server, you can use:"
    echo "ping6 -I isatap1 $remote_server_ipv6"
}

DVHOST_CLOUD_setup_tunnel_and_forward() {
    sudo apt-get install socat
    DVHOST_CLOUD_setup_socat_tunnel
    echo "Tunnel setup complete. Traffic is being forwarded to $dest_ipv6."
}

DVHOST_CLOUD_setup_socat_tunnel() {
    read -p "Enter the destination IPv6 address: " dest_ipv6
    read -p "Enter the ports to forward (comma-separated, e.g., 2020,8080,...): " ports

    IFS=',' read -r -a port_array <<< "$ports"

    for port in "${port_array[@]}"; do
        echo "Setting up tunnel for port $port..."
        sudo socat TCP6-LISTEN:$port,fork TCP6:[$dest_ipv6]:$port &
    done

    echo "All specified ports are being forwarded."
}

DVHOST_CLOUD_delete_tunnel_and_forward() {
    sudo nft delete table ip6 nat
}

DVHOST_CLOUD_delete_tunnel() {
    sudo ip tunnel del isatap1
    echo "Tunnel deleted successfully."
}

DVHOST_CLOUD_cleanup_socat_tunnel() {
    read -p "Enter the ports to stop forwarding (comma-separated, e.g., 2020,8080,...): " ports
    IFS=',' read -r -a port_array <<< "$ports"

    for port in "${port_array[@]}"; do
        echo "Stopping tunnel for port $port..."
        pids=$(pgrep -f "socat TCP6-LISTEN:$port")
        if [ -n "$pids" ]; then
            sudo kill $pids
            echo "Tunnel for port $port has been stopped."
        else
            echo "No active tunnel found for port $port."
        fi
    done
}

DVHOST_CLOUD_ip_to_hex() {
    local ip=$1
    echo $(echo $ip | awk -F. '{printf("%02x%02x:%02x%02x",$1,$2,$3,$4)}')
}

DVHOST_CLOUD_require_command
DVHOST_CLOUD_MAIN
