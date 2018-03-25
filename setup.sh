#!/usr/bin/env bash

PREREQUISITES="apache2 bridge-utils dnsmasq git hostapd iptables-persistent libapache2-mod-wsgi macchanger python-pip python-flask"

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

# Get the script folder
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

copy_with_backup () {
	# If the destination file exists, back it up
	if [ -f $2 ] then
		mv -f ${2} ${2}.rogueap-old
	cp -f ${1} ${2}
}

echo -n "Copying config files..."
copy_with_backup ${SCRIPT_DIR}/cfg/htaccess.rogueap /var/www/html/.htaccess
copy_with_backup ${SCRIPT_DIR}/cfg/dnsmasq.conf.rogueap /etc/dnsmasq.conf
copy_with_backup ${SCRIPT_DIR}/cfg/hostapd.conf.rogueap /etc/hostapd/hostapd.conf
copy_with_backup ${SCRIPT_DIR}/cfg/interfaces.rogueap /etc/network/interfaces
copy_with_backup ${SCRIPT_DIR}/cfg/override.conf.rogueap /etc/apache2/conf-available/override.conf
copy_with_backup ${SCRIPT_DIR}/cfg/rules.v4.rogueap /etc/iptables/rules.v4
echo "done!"

echo -n "Modifying config files..."
sed -i -- 's/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/g' /etc/sysctl.conf
sed -i -- 's/#DAEMON_CONF=""/DAEMON_CONF="\/etc\/hostapd\/hostapd.conf"/g' /etc/default/hostapd
sed -i -- 's/ENABLED=0/ENABLED=1/g' /etc/default/dnsmasq
echo "done!"

echo -n "Configuring Apache..."
a2enconf override
a2enmod rewrite
echo "done!"

echo -n "Disable DHCP..."
update-rc.d dhcpcd disable
echo "done!"

echo -n "Enable dnsmasq..."
systemctl enable dnsmasq
echo "done!"

echo -n "Enable hostapd..."
systemctl enable hostapd
echo "done!"

echo "All done! Reboot to apply changes."

# echo "Configuring..."
# cp -f cfg/hostapd.conf /etc/hostapd/
# cp -f cfg/hostapd /etc/default/
# cp -f cfg/macchanger /etc/default/
# cp -f cfg/dnsmasq.conf /etc/

# cp -f cfg/.htaccess /var/www/html/
# chown -R www-data:www-data /var/www/html
# chown root:www-data /var/www/html/.htaccess
# cp -f override.conf /etc/apache2/conf-available/
# ln -s /etc/apache2/conf-available/override.conf /etc/apache2/conf-enabled/override.conf
# ln -s /etc/apache2/mods-available/rewrite.load /etc/apache2/mods-enabled/rewrite.load

# cp -f rc.local /etc/
