# Kerberit ʕʘ̅͜ʘ̅ʔ

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Bash](https://img.shields.io/badge/Made%20with-Bash-1f425f.svg)](https://www.gnu.org/software/bash/)
[![Platform](https://img.shields.io/badge/Platform-Linux-blue.svg)](https://www.linux.org/)

**Kerberit** is an automated Kerberos exploitation toolkit designed for penetration testing in Active Directory environments. It streamlines the discovery and exploitation of Kerberos tickets and keytab files on Linux systems, making it an essential tool for red team operations.

## Key Features

- **Automated Discovery**: Finds keytab and ccache files across the filesystem
- **Interactive Analysis**: User-friendly menus with colored output and clear feedback
- **Multiple Attack Vectors**: 
  - Pass-the-Key attacks using keytab files
  - Pass-the-Ticket attacks using ccache files
  - Hash extraction from keytabs
- **Privilege Escalation**: Integrates with Linikatz for memory-based credential extraction
- **Tool Integration**: Works seamlessly with Impacket, Evil-WinRM, and other AD tools
- **Smart Filtering**: Highlights readable files and shows permissions
- **Environment Detection**: Checks AD join status and Kerberos configuration

## 📋 Prerequisites

### Required Tools
- `kinit` - Kerberos authentication
- `klist` - Kerberos ticket listing
- `wget` or `curl` - File downloading

### Optional Tools (for extended functionality)
- `impacket-ticketConverter` - Convert tickets to kirbi format
- `keytabextract.py` - Extract hashes from keytabs ([KeyTabExtract](https://github.com/sosdave/KeyTabExtract))
- `linikatz.sh` - Linux memory credential extraction ([Linikatz](https://github.com/CiscoCXSecurity/linikatz))

## 🚀 Installation

```bash
# Clone the repository
git clone https://github.com/imranelalami/kerberit.git
cd kerberit

# Make the script executable
chmod +x kerberit.sh

# Run the tool
./kerberit.sh
```

## 🎮 Usage

### Basic Usage
```bash
./kerberit.sh
```

### Root Privileges (Recommended)
```bash
sudo ./kerberit.sh
```

> **Note**: Running with root privileges enables Linikatz functionality for memory-based credential extraction.

## 🔍 Attack Scenarios

### 1. Keytab File Exploitation
When keytab files are discovered:
- Extract service account credentials
- Perform pass-the-key attacks
- Obtain Kerberos tickets for lateral movement

### 2. Ccache File Reuse
When ccache files are found:
- Import existing Kerberos tickets
- Bypass authentication for privileged accounts
- Convert tickets for use in Windows environments

### 3. Memory Credential Extraction
With root privileges:
- Extract credentials from process memory
- Discover cached passwords and tickets
- Perform comprehensive credential harvesting

##  Menu Options

1. **Find and analyze keytab files** - Locate and examine keytab files for exploitation
2. **Find and use ccache files** - Discover and import existing Kerberos tickets
3. **Search for both file types** - Comprehensive search for all Kerberos artifacts
4. **Check Active Directory status** - Verify domain join status and configuration
5. **Check cronjobs for Kerberos scripts** - Find automated Kerberos operations
6. **Run linikatz** - Memory-based credential extraction (requires root)
7. **Exit program** - Clean exit




## Integration Points
- **Impacket Tools**: Ready for `-k` flag usage
- **Evil-WinRM**: Kerberos authentication support
- **Custom Scripts**: Exported environment variables



##  Acknowledgments

- [Linikatz](https://github.com/CiscoCXSecurity/linikatz) - Linux credential extraction
- [KeyTabExtract](https://github.com/sosdave/KeyTabExtract) - Keytab hash extraction
- [Impacket](https://github.com/SecureAuthCorp/impacket) - Network protocol implementations


---

**Happy Hunting! ʕʘ̅͜ʘ̅ʔ**
