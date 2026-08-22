#!/bin/bash
# REPARACION v5.2 — instalar, purgar backup obsoleto, verificar, re-pack
echo "== 1. INSTALAR v5.2 =="
for f in openssh systemdns badvpn udpcustom dropbear checkuser ssl slowdns hysteria v2ray zipvpn; do
    mv "/tmp/deploy_protocolos@$f.sh" "/etc/movivip/protocolos/$f.sh" || echo "MV_FAIL $f"
done
mv "/tmp/deploy_usuarios@menu.sh" "/etc/movivip/usuarios/menu.sh" || echo "MV_FAIL usuarios"

echo "== 2. PURGAR BACKUP OBSOLETO (v5.1) de los 12 =="
for f in openssh systemdns badvpn udpcustom dropbear checkuser ssl slowdns hysteria v2ray zipvpn; do
    rm -f "/etc/movivip/.pack-backup/protocolos/$f.sh"
done
rm -f /etc/movivip/.pack-backup/usuarios/menu.sh

echo "== 3. CRLF + CHMOD =="
find /etc/movivip/protocolos -maxdepth 1 -name '*.sh' -exec sed -i 's/\r$//' {} +
sed -i 's/\r$//' /etc/movivip/usuarios/menu.sh
chmod +x /etc/movivip/protocolos/*.sh /etc/movivip/usuarios/menu.sh

echo "== 4. VERIFICAR PARCHE PRESENTE EN VPS (plain) =="
P=0; F=0
for f in openssh systemdns badvpn udpcustom dropbear checkuser ssl slowdns hysteria v2ray zipvpn; do
    if grep -q "movivip_footer" "/etc/movivip/protocolos/$f.sh" && grep -q "nav_pick" "/etc/movivip/protocolos/$f.sh"; then
        P=$((P+1))
    else
        echo "SIN_PARCHE: $f"; F=$((F+1))
    fi
done
if grep -q "movivip_footer" /etc/movivip/usuarios/menu.sh; then P=$((P+1)); else echo "SIN_PARCHE: usuarios"; F=$((F+1)); fi
echo "PARCHEADOS=$P SIN_PARCHE=$F"
[[ $F -gt 0 ]] && { echo "ABORTAR: faltan parches"; exit 1; }

echo "== 5. SINTAXIS =="
for f in openssh systemdns badvpn udpcustom dropbear checkuser ssl slowdns hysteria v2ray zipvpn; do
    bash -n "/etc/movivip/protocolos/$f.sh" 2>&1 | head -1
done
bash -n /etc/movivip/usuarios/menu.sh

echo "== 6. RE-PACK (solo los 12 plain; resto ya packed se saltan) =="
bash /etc/movivip/tools/ofuscar.sh /etc/movivip 2>&1 | tail -2

echo "== 7. STUBS SIN EXIT =="
tail -c 80 /etc/movivip/protocolos/openssh.sh | grep -q 'exit \$?' && echo "MAL_STUB" || echo "STUB_SEGURO"

echo "== 8. BACKUP FRESCO DE LOS 12 =="
C=0
for f in openssh systemdns badvpn udpcustom dropbear checkuser ssl slowdns hysteria v2ray zipvpn; do
    [[ -f "/etc/movivip/.pack-backup/protocolos/$f.sh" ]] && C=$((C+1))
done
[[ -f /etc/movivip/.pack-backup/usuarios/menu.sh ]] && C=$((C+1))
echo "BACKUPS_FRESCOS=$C/12"
exit 0
