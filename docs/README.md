# Building a Rogue AP with the Raspberry Pi Zero W

I embarked upon a journey of configuration to get a Raspberry Pi Zero W to act as a WiFi hotspot and serve up a little Python web app to anyone who connected to it. In researching the topic, I came across this posting from Braindead Security: [Building a Rogue Captive Portal for Raspberry Pi Zero W](https://braindead-security.blogspot.com/2017/06/building-rogue-captive-portal-for.html)

It was almost exactly what I wanted, except for a few things:

1. It was written for Raspbian Jessie Lite. I wanted to use the latest Raspbian Stretch Lite.
2. It set up the system for PHP. I wanted to use Python with Flask and WSGI.
3. It used a hackish startup script in /etc/rc.local. I wanted to figure out how to set up all of the services properly through their respective configuration files instead of brute-forcing it.

So, I've borrowed heavily from Braindead's tutorial, but I've updated it to achieve my goals. Unlike Braindead's tutorial, this one will not comprehensively cover everything needed to get a functioning Rogue AP set up to steal login credentials. I focus more on the Raspian configuration required to create an access point and have it direct all traffic to a web app. I don't bother to illustrate how to write an app that does anything interesting.

## TL;DR

On a fresh install of Raspbian Stretch Lite, clone [https://github.com/jerryryle/rogue_ap](https://github.com/jerryryle/rogue_ap) and run setup.sh, then reboot. The Pi needs only a power supply and a wireless adapter on wlan0; an internet connection is not required.

## Components

You will need the following:

* Raspberry Pi Zero W - though any Raspberry Pi model should work as long as it has a wireless adapter (built in or connected via USB)
* Micro SD card - I'd recommend at least a 4GB class 10 card
* HDMI cable and HDMI-compatible monitor or TV
* USB OTG cable and 2A AC adapter for power
* Keyboard and micro USB adapter or powered USB hub
* WiFi
* Computer with SD card reader to download Raspbian and install it onto the SD card
* Computer or phone with WiFi to test the Rogue AP

## Preparation

First, you need to get the Raspberry Pi up and running. Download the latest image of Raspbian Stretch Lite from [https://www.raspberrypi.org/downloads/raspbian/](https://www.raspberrypi.org/downloads/raspbian/)

For writing the image to your SD card, Braindead recommends simplifying the process by using Etcher from [https://etcher.io](https://etcher.io).

Insert the SD card in your computer and use Etcher to copy the Raspbian image to the SD card (it will overwrite any data currently on the card).

![Etcher screenshot](etcher_screen_shot.png)

When Etcher has finished copying the image, remove the SD card from your computer, plug it into the Raspberry Pi, connect a keyboard and monitor, and plug in the AC adapter. The system should boot to a login prompt. Log in using the default username `pi` and password `raspberry`.

In order to configure the device, you'll need to configure the Raspberry Pi to connect to your WiFi network. Type this command to edit the wireless configuration:
```bash
sudo nano /etc/wpa_supplicant/wpa_supplicant.conf
```

To the end of the file, add the following lines, substituting the name of your local access point and its corresponding password:
```text
network={
    ssid="WiFi Network"
    psk="password"
}
```

To save the file and exit, type `Ctrl-X`, then `y`, then `Enter`. Then, enter the following command to load the new network configuration:
```bash
sudo service networking restart
```

Next, update the system with the following command:
```bash
sudo apt-get update && sudo apt-get dist-upgrade -y
```

After the system has updated, install the additional required packages:
```bash
sudo apt-get install apache2 bridge-utils dnsmasq git hostapd iptables-persistent libapache2-mod-wsgi macchanger python-pip python-flask
```

During the installation of the `macchanger` package, you will be asked whether you'd like `macchanger` to run automatically. Select 'Yes' with the arrow keys and press `Enter`:
![macchanger installation prompt](macchanger.png)

Here's what you're installing and why:

* **apache2** - This is the web server that will serve up your content
* **bridge-utils** - Utilities for creating network bridge interfaces. Although hostapd can create the bridge interface for you, it doesn't give you control over the IP address of the interface. Because you need to fix the bridge's IP address, you have to create and configure the interface manually with the tools in this package.
* **dnsmasq** - This provides DNS and DHCP services. You'll configure this to hijack all DNS requests and give responses that direct browsers to your web server.
* **git** - This is needed to clone the repository that contains setup scripts and configuration files. (If you're planning to do all of the setup by hand, you don't need this)
* **hostapd** - This allows you to create a WiFi access point.
* **iptables-persistent** - This allows you to store routing rules in a configuration file that is loaded upon startup. This prevents us from having to manually hack the rules into a startup script.
* **libapache2-mod-wsgi** - This is an Apache module that allows you to host a Python web application.
* **macchanger** - This will randomly change your Raspberry Pi's WiFi MAC address. This makes it difficult for someone to track your Rogue AP or to blacklist it by its MAC address.
* **python-pip** - This is a Python package installer. It's needed to install the Python web app that will control what your Rogue AP actually does.
* **python-flask** - This is a powerful, but lightweight web framework for Python. You can use it to make your Rogue AP do all sorts of fun stuff.

When the installation finishes, restart the Raspberry Pi:
```bash
sudo reboot
```

## Configuring your Rogue AP
### The Quick Way
To configure the system to run the rogue access point, all you need to do is download a repository from GitHub and run the installer. To do this, use these commands (you will be prompted for the name of the WiFi network that your Rogue AP will create):
```bash
git clone https://github.com/jerryryle/rogue_ap.git
cd rogue_ap
sudo ./setup.sh
sudo reboot
```

Once you do this, your Raspberry Pi will lose internet access since you have converted its wireless hardware from a WiFi client to an Access Point.

If you need to restore WiFi so that you can access the internet from your Raspberry Pi, you can use the `restore_wifi.sh` script to disable the Rogue AP and reconnect to your WiFi network. To do this, run these commands (you will be prompted for your WiFi SSID and password):
```bash
cd rogue_ap
sudo ./restore_wifi.sh
sudo reboot
```

### The Manual Way

#### Configuring the Web Server to Run an App
First, you'll want to install your web application and get it running under Apache. The github repo associated with this project contains a skeleton Flask-based app that's intended to run under Apache. You can clone the repo and use it or build your own app. If you want to use a different framework, language, or web server, the configuration is up to you and you can skip over this section.

To install a Flask-based app, switch to the app's folder ("rogueap" in the github repo) and run this command:
```bash
pip install --upgrade --no-deps --force-reinstall .
```

The `--upgrade --no-deps --force-reinstall` flags ensure that the app is upgraded to any newer version if it's already reinstalled, that its dependencies are not reinstalled, and that the app will be reinstalled if it's already installed and there's no newer version. This attempts to guarantee that any changes to your app get installed whenever you run this command.

To configure Apache to run the installed Flask app, follow these instructions: [http://flask.pocoo.org/docs/0.12/deploying/mod_wsgi/](http://flask.pocoo.org/docs/0.12/deploying/mod_wsgi/). In a nutshell, you need to create a `.wsgi` file that imports your installed app and change your Apache site's `VirtualHost` configuration to run it. The linked instructions should walk you through all of this, but you can also inspect the files in this project's github repo to see how I configured it.

#### Configuring the Web Server to Fool Captive Portal Detection

First, we need to add a directory rule to allow `.htaccess` overrides within the `/var/www` folder. This lets us add `.htaccess` files with rules for redirecting special URLs. To allow overrides, create the file `/etc/apache2/conf-available/override.conf` with the following contents:
```apache
<Directory /var/www/>
    Options Indexes FollowSymLinks MultiViews
    AllowOverride All
    Order Allow,Deny
    Allow from all
</Directory>
```

Then enable it with this command:
```bash
sudo a2enconf override
```

Now enable the rewrite module with this command:
```bash
sudo a2enmod rewrite
```

Now we can create rules to redirect special URLs. When you connect certain devices to WiFi, they issue http requests to determine whether internet access is available. We need to ensure that we handle these requests. To do so, create an `.htaccess` file in your web app's wsgi folder (`/var/www/rogueap/` if you're using the github repo's configuration) with these contents:
```apache
Redirect /library/test/success.html /
Redirect /hotspot-detect.html /
Redirect /ncsi.txt /
Redirect /connecttest.txt /
Redirect /fwlink/ /
Redirect /generate_204 /r/204

RewriteEngine on
RewriteCond %{HTTP_USER_AGENT} ^CaptiveNetworkSupport(.*)$ [NC]
RewriteRule ^(.*)$ / [L,R=301]
```

That list came from Braindead Security's tutorial. It contains rules for the captive portal URLs that different device makers use (including one that relies on the user agent string), but it might not be a comprehensive list. The rules redirect requests to the root of the webapp (except `/generate_204`, which redirects to `/r/204`, which is configured to generate a 204 response).

#### Configuring the Access Point
