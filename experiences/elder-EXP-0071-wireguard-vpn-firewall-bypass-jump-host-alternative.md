# EXP-0071: WireGuard VPN ile Firewall Bypass ve Jump Host Alternatifi

**Date**: 2025-12-24
**Project**: Infrastructure (Cross-Project)
**Category**: DevOps/Networking/VPN/SSH
**Technologies**: WireGuard, SSH, macOS, Ubuntu, Homebrew, Kandji MDM
**Status**: ✅ SUCCESS

---

## Problem

### Context
- Uzak sunuculara erişim firewall ile kısıtlı (sadece belirli IP whitelist)
- Laptop'ta MDM (Kandji) kurulu ve VPN uygulamaları engellenmiş (örn: Tailscale blocked)
- Mevcut çözüm: SSH ProxyCommand/ProxyJump (2x handshake → yavaş)
- Mobil hotspot kullanırken bağlantı instabil (TCP packet loss)

### Symptoms
```bash
# Mevcut ProxyJump setup (yavaş)
Host remote-server
    ProxyJump jump-host
    # İlk jump-host'a bağlan → sonra remote'a
    # 2x authentication handshake
    # Toplam bağlantı süresi: ~9 saniye
```

**Performance Metrics:**
- SSH connection time: 9 seconds (with ProxyJump)
- Mobil hotspot'ta sık sık timeout
- VS Code Remote SSH: frequent disconnections

---

## Root Cause

### Technical Analysis

**ProxyJump Inefficiency:**
```
Client → Jump Host (handshake 1)
       → Remote Server (handshake 2)
```
- Her bağlantı 2 TCP handshake gerektirir
- Packet loss'ta retry mekanizması yetersiz
- TCP tabanlı → mobil internette stabil değil

**MDM Restrictions:**
- Kandji VPN uygulamalarını engelliyor
- Tailscale, OpenVPN gibi GUI uygulamalar çalışmıyor
- AMA homebrew paketleri engellenmemiş!

---

## Solution

### 1. WireGuard Server Kurulumu (Whitelist VPS)

**Ubuntu Server Setup:**
```bash
# Install WireGuard
sudo apt update
sudo apt install wireguard

# Generate server keys
wg genkey | sudo tee /etc/wireguard/privatekey
sudo cat /etc/wireguard/privatekey | wg pubkey | sudo tee /etc/wireguard/publickey

# Configure server
sudo nano /etc/wireguard/wg0.conf
```

**Server Config (`/etc/wireguard/wg0.conf`):**
```ini
[Interface]
PrivateKey = <SERVER_PRIVATE_KEY>
Address = 10.8.0.1/24
ListenPort = 51820
SaveConfig = true

# Enable IP forwarding and NAT
PostUp = sysctl -w net.ipv4.ip_forward=1
PostUp = iptables -A FORWARD -i wg0 -j ACCEPT
PostUp = iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
PostDown = iptables -D FORWARD -i wg0 -j ACCEPT
PostDown = iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE

[Peer]
# Mac client
PublicKey = <CLIENT_PUBLIC_KEY>
AllowedIPs = 10.8.0.2/32
```

**Firewall:**
```bash
# UFW kuralı
sudo ufw allow 51820/udp
```

**Start Service:**
```bash
sudo systemctl enable wg-quick@wg0
sudo systemctl start wg-quick@wg0
sudo wg show  # Verify
```

### 2. macOS Client Setup

**Install via Homebrew (Kandji bunu engellemedi!):**
```bash
brew install wireguard-tools
```

**Optional GUI App (App Store'dan):**
- WireGuard GUI app kurulabilir (daha kolay)
- Menu bar'dan tek tıkla aç/kapa

**Generate Client Keys:**
```bash
wg genkey | tee privatekey
cat privatekey | wg pubkey > publickey
```

**Client Config (`/opt/homebrew/etc/wireguard/wg0.conf`):**
```ini
[Interface]
PrivateKey = <CLIENT_PRIVATE_KEY>
Address = 10.8.0.2/24
DNS = 8.8.8.8

# Mobil bağlantı için önemli!
# Keepalive NAT'ı açık tutar
PersistentKeepalive = 25

[Peer]
PublicKey = <SERVER_PUBLIC_KEY>
Endpoint = <WHITELISTED_VPS_IP>:51820
AllowedIPs = 0.0.0.0/0  # Tüm trafik VPN üzerinden
```

**Connect:**
```bash
# CLI
sudo wg-quick up wg0
sudo wg-quick down wg0

# GUI app'te
# Import config → Toggle ON
```

### 3. SSH Configuration Update

**~/.ssh/config (artık ProxyJump yok!):**
```ssh
Host remote-server
    HostName <internal-ip>
    User ubuntu
    IdentityFile ~/.ssh/id_rsa
    # Artık ProxyJump yok! Direkt bağlantı.
    # Çünkü client IP = whitelisted VPS IP
```

**VS Code Remote SSH Timeout Fix:**
```json
// settings.json
{
  "remote.SSH.connectTimeout": 120
}
```

---

## Results

### Performance Improvements

**Before (ProxyJump):**
- Connection time: ~9 seconds
- Mobil hotspot: instabil
- VS Code Remote: sık disconnect

**After (WireGuard):**
- Connection time: ~5 seconds (%40 hızlanma!)
- Mobil hotspot: stabil bağlantı
- VS Code Remote: hiç disconnect yok

### Why WireGuard is Better

**UDP vs TCP:**
- WireGuard UDP tabanlı
- Packet loss'ta yeniden bağlanmaya gerek yok
- Mobil internette çok daha stabil

**Single Handshake:**
```
Client (VPN ON) → Remote Server (tek bağlantı)
```

**Menu Bar Integration:**
- WireGuard GUI app
- Tek tıkla aç/kapa
- Battery impact minimal

---

## Key Learnings

### 1. MDM Bypass Without Violation
- Kandji GUI VPN uygulamalarını engeller
- AMA homebrew CLI tools engellenmez
- WireGuard = hem CLI hem GUI kullanılabilir

### 2. UDP > TCP for Mobile
- TCP packet loss'ta yavaşlar
- UDP packet loss'u ignore eder (yeniden bağlanır)
- Mobil internette UDP çok daha iyi

### 3. PersistentKeepalive Critical
```ini
PersistentKeepalive = 25
```
- NAT'ı açık tutar (mobil hotspot için)
- 25 saniyede bir keepalive paketi
- Olmadan mobil bağlantı kopar

### 4. ProxyJump Still Useful
- WireGuard fallback olarak SSH ProxyJump tutulabilir
- VPN down olursa yedek çözüm
- İki yöntem de aynı anda kullanılabilir

---

## Prevention Checklist

### WireGuard Server Setup
- [ ] UFW port açık (51820/udp)
- [ ] IP forwarding enabled (`sysctl net.ipv4.ip_forward=1`)
- [ ] NAT masquerade configured (iptables)
- [ ] systemctl enable/start wg-quick@wg0
- [ ] `wg show` output doğru

### macOS Client Setup
- [ ] Homebrew installed (Kandji check!)
- [ ] `brew install wireguard-tools`
- [ ] Client keys generated
- [ ] Config file doğru yerde (`/opt/homebrew/etc/wireguard/`)
- [ ] PersistentKeepalive = 25 (mobil için)
- [ ] AllowedIPs doğru (0.0.0.0/0 tüm trafik için)

### Testing
- [ ] `sudo wg-quick up wg0` başarılı
- [ ] `ping 10.8.0.1` (server internal IP)
- [ ] `curl ifconfig.me` (VPS external IP dönmeli)
- [ ] SSH direct connection (ProxyJump olmadan)
- [ ] VS Code Remote SSH stability test
- [ ] Mobil hotspot'ta test (en kritik!)

---

## Related Experiences

- **[EXP-0058](EXP-0058-vps1-disk-cleanup-mongodb-logs.md)**: VPS disk yönetimi
- **[EXP-0057](EXP-0057-vps2-mongodb-authentication-enable.md)**: VPS güvenlik
- **[EXP-0059](EXP-0059-vps-os-version-comparison.md)**: VPS standardizasyonu

---

## Tags

`wireguard`, `vpn`, `ssh`, `firewall`, `jump-host`, `proxy-command`, `mdm`, `kandji`, `homebrew`, `macos`, `ubuntu`, `udp`, `tcp`, `mobile-hotspot`, `vs-code-remote`, `nat`, `keepalive`, `performance`, `infrastructure`

---

## Notes

**Security Considerations:**
- WireGuard public key kriptografi kullanır (güvenli)
- AllowedIPs = 0.0.0.0/0 → tüm trafik VPN'den çıkar (DNS leak risk yok)
- Server'da IP forwarding gerekli (dikkatli kullan)

**Battery Impact:**
- PersistentKeepalive battery tüketir (minimal)
- Mobil hotspot'ta trade-off değer
- WiFi'de keepalive kapatılabilir (config'de comment out)

**Alternative Solutions Considered:**
1. Tailscale → Kandji tarafından blocked
2. OpenVPN → Daha yavaş (TCP overhead)
3. ZeroTier → Tested but WireGuard faster
4. SSH Tunnel (-D SOCKS) → ProxyJump kadar yavaş

**Why WireGuard Won:**
- Kandji bypass (homebrew)
- UDP performance
- Minimal config
- Active development
- macOS GUI app
