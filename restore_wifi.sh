#!/usr/bin/env bash

if [ "$(id -u)" != "0" ]; then
	echo "This must be run as root." 1>&2
	exit 1
fi

# Get the script folder
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

echo "Enter WiFi SSID:"
read SSID

echo "Enter WiFi PSK:"
read PSK

echo -n "Copying config files..."
cp -f ${SCRIPT_DIR}/cfg/interfaces.wifi /etc/network/interfaces
echo "done!"

echo -n "Modifying config files..."
sed -i -- 's/net.ipv4.ip_forward=1/#net.ipv4.ip_forward=1/g' /etc/sysctl.conf
sed -i -- 's/DAEMON_CONF="\/etc\/hostapd\/hostapd.conf"/#DAEMON_CONF=""/g' /etc/default/hostapd
sed -i -- 's/ENABLED=1/ENABLED=0/g' /etc/default/dnsmasq
echo "done!"

echo -n "Enable DHCP..."
update-rc.d dhcpcd enable
echo "done!"

echo -n "Disable dnsmasq..."
systemctl disable dnsmasq
echo "done!"

echo -n "Disable hostapd..."
systemctl disable dnsmasq
echo "done!"

cat > /etc/wpa_supplicant/wpa_supplicant.conf <<EOF
ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev
update_config=1
network={
    ssid="${SSID}"
    psk="${PSK}"
}
EOF

echo "All done! Reboot to apply changes."
