# Copilot Session Summary
## Goal
Consolidate ALL iptables rules from VPS 151.245.32.224 into install.sh so the next fresh install has identical network configuration.

## Constraints & Preferences
- **DO NOT MODIFY THE VPS** — only modify scripts
- Source of truth: `C:\Users\ADMIN\Desktop\vps\scrip vps todo\`
- VPS: 151.245.32.224, root, RixjJkcOb1c69a8iIDWb, port 22
- Kernel 5.15.0-187-generic (NO 3-band FQ support)
- DNAT rules already exist in udpcustom.sh and zipvpn.sh — user says "leave them as is, don't duplicate in install.sh"
- User confirmed: add ALL 4 missing items to install.sh

## Progress
### Completed
- SSH connected to VPS, captured full iptables state (filter/nat/mangle)
- Compared VPS config vs install.sh — found gaps
- User approved plan: add 4 items to install.sh
- Plan file created: `C:\Users\ADMIN\Desktop\vps\scrip vps todo\PLAN-INSTALL-IPTABLES.md`

### In Progress
- Awaiting user decision on DNAT version (A=complete, B=simplified without DNAT)

### Blocked
- Plan mode active — cannot edit files yet

## Key Decisions
- **DNAT**: User said "if they're already in protocols, not necessary in install.sh" → Version B (simplified, no DNAT)
- **INPUT ACCEPT**: Add all 10 rules (2100, 5667, 6000:19999, 20000:29999, 7200, 80, 443, 8080, 8443, 22)
- **MOVIVIP_OUT**: Create chain in install.sh (currently only created by online.sh)
- **MANGLE DSCP**: Add gaming priority marking for Free Fire (7000-7999), COD (3478-3480), PUBG (8000-9000)
- **iptables-save**: Persist rules to /etc/iptables/rules.v4

## Next Steps
1. User chooses DNAT version (A or B)
2. Implement chosen version in install.sh after line 355 (tc qdisc add)
3. Update echo on line 357 to include "iptables"
4. Verify with bash commands on VPS

## Critical Context
- install.sh line 355: `tc qdisc add dev "$IFACE_NET" root fq quantum 1492 initial_quantum 14920 flow_limit 1000 limit 10000 horizon 0 refill_delay 10 low_rate_threshold 10Mbit`
- VPS iptables filter: 13 INPUT ACCEPT rules
- VPS iptables nat: 5 DNAT rules + MASQUERADE (created by zipvpn.sh/udpcustom.sh)
- VPS iptables mangle: EMPTY (to be added as NEW)
- VPS MOVIVIP_OUT: Empty chain (created by online.sh)

## File Operations
### Read
- `C:\Users\ADMIN\Desktop\vps\scrip vps todo\install.sh` (lines 240-454)
- `C:\Users\ADMIN\Desktop\vps\scrip vps todo\protocolos\udpcustom.sh` (lines 140-214)
- `C:\Users\ADMIN\Desktop\vps\scrip vps todo\protocolos\zipvpn.sh` (lines 250-372)
- `C:\Users\ADMIN\Desktop\vps\scrip vps todo\usuarios\online.sh` (lines 105-134)

### Created
- `C:\Users\ADMIN\Desktop\vps\scrip vps todo\PLAN-INSTALL-IPTABLES.md`
