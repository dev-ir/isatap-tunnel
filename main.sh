#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
plain='\033[0m'
NC='\033[0m' # No Color

# check root
[[ $EUID -ne 0 ]] && echo -e "${RED}Fatal error: ${plain} Please run this script with root privilege \n " && exit 1


FREEZVPN_install_jq() {
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

FREEZVPN_require_command(){
    apt install python3-pip -y
    sudo apt-get install socat -y
    FREEZVPN_install_jq
    if ! command -v pv &> /dev/null; then
        echo "pv could not be found, installing it..."
        sudo apt update
        sudo apt install -y pv
    fi
}

FREEZVPN_menu(){
    clear
    SERVER_IP=$(hostname -I | awk '{print $1}')
    SERVER_COUNTRY=$(curl -sS "http://ip-api.com/json/$SERVER_IP" | jq -r '.country')
    SERVER_ISP=$(curl -sS "http://ip-api.com/json/$SERVER_IP" | jq -r '.isp')
     
                                                                            
    echo "+-----------------------------------------------------------------------+"                                                                                                
    echo " ________                                          __     __  _______   __    __ "
    echo "|        \                                        |  \   |  \|       \ |  \  |  \"
    echo "| $$$$$$$$  ______    ______    ______   ________ | $$   | $$| $$$$$$$\| $$\ | $$"
    echo "| $$__     /      \  /      \  /      \ |        \| $$   | $$| $$__/ $$| $$$\| $$"
    echo "| $$  \   |  $$$$$$\|  $$$$$$\|  $$$$$$\ \$$$$$$$$ \$$\ /  $$| $$    $$| $$$$\ $$"
    echo "| $$$$$   | $$   \$$| $$    $$| $$    $$  /    $$   \$$\  $$ | $$$$$$$ | $$\$$ $$"
    echo "| $$      | $$      | $$$$$$$$| $$$$$$$$ /  $$$$_    \$$ $$  | $$      | $$ \$$$$"
    echo "| $$      | $$       \$$     \ \$$     \|  $$    \    \$$$   | $$      | $$  \$$$"
    echo " \$$       \$$        \$$$$$$$  \$$$$$$$ \$$$$$$$$     \$     \$$       \$$   \$$"
    echo "+-----------------------------------------------------------------------+"                                                                                                
    echo -e "| Telegram Channel : ${GREEN}@FREEZVPN ${NC}|"
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

FREEZVPN_MAIN(){
    clear
    FREEZVPN_menu "| 1  - Get IPv6 \n| 2  - Setup Tunnel \n| 3  - Status \n| 0  - Exit"
    read -p "Enter your choice: " choice
    
    case $choice in
        1)
            FREEZVPN_GET_LOCAL_IP
        ;;
        2)
            FREEZVPN_TUNNEL
        ;;
        3)
            FREEZVPN_check_status
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

FREEZVPN_TUNNEL(){
    FREEZVPN_menu "| 1  - Setup Tunnel  \n| 2  - Remove Tunnel \n| 0  - Exit"
    read -p "Enter your choice: " choice

    case $choice in
        1)
            FREEZVPN_setup_tunnel_and_forward
        ;;
        2)
            FREEZVPN_cleanup_socat_tunnel
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

FREEZVPN_check_status() {
    if ip link show isatap1 &> /dev/null; then
        echo -e "\e[32mTunnel is UP.\e[0m"
    else
        echo -e "\e[31mTunnel is DOWN.\e[0m"
    fi
}

FREEZVPN_GET_LOCAL_IP(){
    clear
    FREEZVPN_menu "| 1  - IRAN \n| 2  - KHAREJ  \n| 3 - Remove \n| 0  - Exit"
    read -p "Enter your choice: " choice
    
    case $choice in
        1)
            read -p "Enter the IPv4 address of Server 1 (This server): " server1_ip
            read -p "Enter the IPv4 address of Server 2 (Remote server): " server2_ip
            FREEZVPN_create_tunnel_and_ping $server1_ip $server2_ip
        ;;
        2)
            read -p "Enter the IPv4 address of Server 2 (This server): " server2_ip
            read -p "Enter the IPv4 address of Server 1 (Remote server): " server1_ip
            FREEZVPN_create_tunnel_and_ping $server2_ip $server1_ip
        ;;
        3)
            FREEZVPN_delete_tunnel
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

FREEZVPN_create_tunnel_and_ping() {
    local this_server_ip=$1
    local remote_server_ip=$2
    local this_server_hex=$(FREEZVPN_ip_to_hex $this_server_ip)
    local remote_server_hex=$(FREEZVPN_ip_to_hex $remote_server_ip)
    local this_server_ipv6="fe80::200:5efe:$this_server_hex"
    local remote_server_ipv6="fe80::200:5efe:$remote_server_hex"

    sudo ip tunnel add isatap1 mode isatap local $this_server_ip
    sudo ip link set isatap1 up
    sudo ip -6 addr add $this_server_ipv6/64 dev isatap1
    sudo sysctl -w net.ipv6.conf.all.forwarding=1
    echo "Tunnel created successfully for $this_server_ip."

    echo "=========================================="
    echo -e "| IPv6 address of the this server: ${RED}$this_server_ipv6%isatap1${NC} |"
    echo "=========================================="

    echo "Pinging the remote server ($remote_server_ipv6)..."
    ping6 -I isatap1 $remote_server_ipv6 -c 4

    echo "To manually ping the remote server, you can use:"
    echo "ping6 -I isatap1 $remote_server_ipv6"


    echo "Configuring ISATAP to persist after reboot..."


    if [ ! -f /etc/rc.local ]; then
        echo "#!/bin/bash" | sudo tee /etc/rc.local > /dev/null
        sudo chmod +x /etc/rc.local
    fi


    sudo sed -i '/exit 0/d' /etc/rc.local
    echo "ip tunnel add isatap1 mode isatap local $this_server_ip" | sudo tee -a /etc/rc.local > /dev/null
    echo "ip link set isatap1 up" | sudo tee -a /etc/rc.local > /dev/null
    echo "ip -6 addr add $this_server_ipv6/64 dev isatap1" | sudo tee -a /etc/rc.local > /dev/null
    echo "sysctl -w net.ipv6.conf.all.forwarding=1" | sudo tee -a /etc/rc.local > /dev/null
    echo "exit 0" | sudo tee -a /etc/rc.local > /dev/null

    echo "ISATAP configuration added to /etc/rc.local. It will persist after reboot."

}

FREEZVPN_setup_tunnel_and_forward() {
    sudo apt-get install socat
    FREEZVPN_setup_socat_tunnel
    echo "Tunnel setup complete. Traffic is being forwarded to $dest_ipv6."
}

FREEZVPN_setup_socat_tunnel() {
    read -p "Enter the destination IPv6 address: " dest_ipv6
    read -p "Enter the ports to forward (comma-separated, e.g., 2020,8080,...): " ports

    IFS=',' read -r -a port_array <<< "$ports"

    for port in "${port_array[@]}"; do
        echo "Setting up tunnel for port $port..."
        sudo socat TCP6-LISTEN:$port,fork TCP6:[$dest_ipv6]:$port &
    done

    echo "All specified ports are being forwarded."
}

FREEZVPN_delete_tunnel() {
    sudo ip tunnel del isatap1
    echo "Tunnel deleted successfully."
}

FREEZVPN_cleanup_socat_tunnel() {
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

FREEZVPN_ip_to_hex() {
    local ip=$1
    echo $(echo $ip | awk -F. '{printf("%02x%02x:%02x%02x",$1,$2,$3,$4)}')
}

FREEZVPN_require_command
FREEZVPN_MAIN
