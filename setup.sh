#!/usr/bin/env bash


PREREQUISITES="apache2 libapache2-mod-wsgi bridge-utils dnsmasq git hostapd iptables-persistent libapache2-mod-wsgi macchanger python-pip python-flask"

if [ "$(id -u)" != "0" ]; then
	echo "This must be run as root." 1>&2
	exit 1
fi

package_missing () {
	if dpkg --get-selections | grep -q "^$1[[:space:]]*install$" >/dev/null; then
		return 1
	else
		return 0
	fi
}

MISSING_PACKAGES=0
for pkg in $PREREQUISITES; do
	if package_missing $pkg; then
		echo "Missing $pkg"
		MISSING_PACKAGES=1
	fi
done

if [ "${MISSING_PACKAGES}" == "1" ]; then
	echo "Cannot continue until missing packages are installed."
	exit 1
fi

echo "Enter the SSID you would like to use for the Rogue Access Point:"
read SSID

# Get the script folder
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

copy_with_backup () {
	# If the destination file exists, back it up--but only if the backup file does not already exist
	if [ -f $2 ] && [ ! -f $2.rogueap-old ]; then
		mv -f ${2} ${2}.rogueap-old
	fi
	cp -f ${1} ${2}
}

echo "Copying config files..."
copy_with_backup ${SCRIPT_DIR}/cfg/htaccess.rogueap /var/www/html/.htaccess
copy_with_backup ${SCRIPT_DIR}/cfg/dnsmasq.conf.rogueap /etc/dnsmasq.conf
copy_with_backup ${SCRIPT_DIR}/cfg/hostapd.conf.rogueap /etc/hostapd/hostapd.conf
copy_with_backup ${SCRIPT_DIR}/cfg/br0.rogueap /etc/network/interfaces.d/br0
copy_with_backup ${SCRIPT_DIR}/cfg/override.conf.rogueap /etc/apache2/conf-available/override.conf
copy_with_backup ${SCRIPT_DIR}/cfg/rules.v4.rogueap /etc/iptables/rules.v4
echo "done!"

echo "Modifying config files..."
sed -i -- "s/^ssid=.*$/ssid=${SSID}/g" /etc/hostapd/hostapd.conf
sed -i -- 's/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/g' /etc/sysctl.conf
sed -i -- 's/ENABLED=0/ENABLED=1/g' /etc/default/dnsmasq
echo "done!"

echo "Configuring Apache..."
a2enconf override
a2enmod rewrite
echo "done!"

echo "Installing Python Web App..."
pip install --upgrade --no-deps --force-reinstall ${SCRIPT_DIR}/rogueap
echo "done!"

echo "Configuring Web App..."
mkdir -p /var/www/rogueap
copy_with_backup ${SCRIPT_DIR}/cfg/rogueap.wsgi.rogueap /var/www/rogueap/rogueap.wsgi
copy_with_backup ${SCRIPT_DIR}/cfg/000-rogueap.conf.rogueap /etc/apache2/sites-available/000-rogueap.conf
a2dissite 000-default
a2ensite 000-rogueap
echo "done!"

echo "Disabling DHCP..."
update-rc.d dhcpcd disable
echo "done!"

echo "Enabling dnsmasq..."
systemctl enable dnsmasq
echo "done!"

echo "Enabling hostapd..."
systemctl unmask hostapd
systemctl enable hostapd
echo "done!"

echo "Disabling WPA Supplicant..."
cat > /etc/wpa_supplicant/wpa_supplicant.conf <<EOF
ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev
update_config=1
EOF
echo "done!"

echo "All done! Reboot to apply changes."
