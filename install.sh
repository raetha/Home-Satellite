#!/usr/bin/bash

# Confirm configuration files are in place
echo "Have you updated the mopidy config and service files?"
read -p "[Y/N]" -n 1 -r
echo    # (optional) move to a new line
if [[ ! $REPLY =~ ^[Yy]$ ]]
then
	[[ "$0" = "$BASH_SOURCE" ]] && exit 1 || return 1 # handle exits from shell or function but don't exit interactive shell
else
	echo "Please copy mopidy/config/mopidy-sample.conf to mopidy/config/mopidy.conf and edit for your environment."
	echo "Please edit ssytemd/homeassistant-satellite.service and set at least your host and token."
fi

# Set variables
export MOPIDY_PACKAGES="mopidy mopidy-mpd mopidy-iris mopidy-pandora mopidy-jellyfin mopidy-tunein mopidy-snapduck"

# Update All System Packages
sudo apt -y update && sudo apt -y full-upgrade
sudo apt -y autopurge

# Remove unneccesary packages from Raspberry Pi OS Desktop
sudo apt -y purge firefox rpi-firefox-mods geany thonny vlc
sudo apt -y autopurge

# Set raspi-config options
sudo raspi-config nonint do_boot_behaviour B2
sudo raspi-config nonint do_expand_rootfs

# Disable onboard audio DAC
read -p "Diable onboard audio? [Y/N]" -n 1 -r
echo    # (optional) move to a new line
if [[ $REPLY =~ ^[Yy]$ ]]
then
	sudo sed -i 's/^dtparam=audio=on$/#dtparam=audio=on/' /boot/config.txt
	sudo sed -i 's/^dtparam=audio=on$/#dtparam=audio=on/' /boot/firmware/config.txt
fi

# Configure GPIO DAC - Waveshare WM8960
read -p "Install Waveshare WM8960 driver? [Y/N]" -n 1 -r
echo    # (optional) move to a new line
if [[ $REPLY =~ ^[Yy]$ ]]
then
	git clone https://github.com/waveshare/WM8960-Audio-HAT
	cd WM8960-Audio-HAT
	sudo ./install.sh
	sudo sed -i 's/^#dtparam=i2c_arm=on$/dtparam=i2c_arm=on/' /boot/firmware/config.txt
	echo "dtoverlay=i2s-mmap" | sudo tee -a /boot/firmware/config.txt > /dev/null
fi

# Copy required files to /opt - TODO just checkout to /opt???
sudo mkdir /opt/Home-Satellite
sudo chown -R $USER:$USER /opt/Home-Satellite
cp -pr systemd /opt/Home-Satellite/

# PulseAudio - Headless only
#sudo apt -y install pulseaudio pulsemixer pulseaudio-utils libpulse0
#sudo apt -y install pulseaudio pulsemixer pulseaudio-utils libpulse0 pulseaudio-module-bluetooth
#sudo systemctl --global disable --now pulseaudio.service pulseaudio.socket
#sudo systemctl --global mask --now pulseaudio.service pulseaudio.socket
#sudo sed -i 's/^.*autospawn.*$/autospawn = no/' /etc/pulse/client.conf
#sudo groupmod -a -U pulse video
#sudo groupmod -a -U pulse bluetooth
#sudo groupmod -a -U root pulse-access
#sudo groupmod -a -U $USER pulse-access
#newgrp pulse-access
#sudo ln -s /opt/Home-Satellite/systemd/pulseaudio.service /lib/systemd/system/pulseaudio.service
#sudo systemctl daemon-reload
#sudo systemctl enable --now pulseaudio.service
##journalctl -u pulseaudio.service -f
# TODO replace with amixer cli commands
#alsamixer # set mic to 100, speaker to 50
#pulsemixer # set mic to 100, speaker to 50

# PipeWire - TODO
sudo apt -y install pipewire pipewire-pulse pulseaudio pulseaudio-module-bluetooth pulseaudio-utils libpulse0
sudo raspi-config nonint do_audioconf 2

# Snapclient
sudo apt -y install snapclient
sudo systemctl disable --now snapclient.service # Mopidy will launch this via SnapDuck

# Mopidy
cp -pr mopidy /opt/Home-Satellite/
sudo apt -y install libavcodec59 build-essential python3-dev python3-pip python3-venv \
	python3-gst-1.0 gir1.2-gstreamer-1.0 gir1.2-gst-plugins-base-1.0 gstreamer1.0-plugins-good \
	gstreamer1.0-plugins-ugly gstreamer1.0-tools gstreamer1.0-pulseaudio gstreamer1.0-libav
python -m venv --system-site-packages /opt/Home-Satellite/mopidy
source /opt/Home-Satellite/mopidy/bin/activate && \
	python3 -m pip install --upgrade $MOPIDY_PACKAGES && \
	deactivate
sudo ln -s /opt/Home-Satellite/systemd/mopidy.service /lib/systemd/user/mopidy.service
systemctl --user daemon-reload
systemctl --user enable --now mopidy.service

# Shairport-sync
sudo apt -y install shairport-sync
sudo sed -i 's/^.*\toutput_backend =.*$/\toutput_backend = "pa";/' /etc/shairport-sync.conf
sudo sed -i 's/^.*\tallow_session_interruption =.*$/\tallow_session_interruption = "yes";/' /etc/shairport-sync.conf
sudo systemctl disable --now shairport-sync.service
sudo ln -s /opt/Home-Satellite/systemd/shairport-sync.service /lib/systemd/user/shairport-sync.service
systemctl --user daemon-reload
systemctl --user enable --now shairport-sync.service

# Docker - docker method for Wyoming wake word installs
## Add Docker's official GPG key:
#sudo apt -y install ca-certificates curl gnupg
#sudo install -m 0755 -d /etc/apt/keyrings
#curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
#sudo chmod a+r /etc/apt/keyrings/docker.gpg
## Add the repository to Apt sources:
#echo \
#	"deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \
#	"$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" | \
#	sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
#sudo apt -y update
#sudo apt -y install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
#sudo groupmod -a -U $USER docker
#cp -pr docker /opt/Home-Satellite/

# Wyoming Porcupine1 - docker method for Wyoming wake word installs
#docker compose -f /opt/Home-Satellite/docker/wyoming-porcupine1.yml up -d

# Wyoming Porcupine1 - local method
sudo apt -y install python3 python3-pip python3-venv
python -m venv --system-site-packages /opt/Home-Satellite/wyoming-porcupine1
source /opt/Home-Satellite/wyoming-porcupine1/bin/activate && \
        python3 -m pip install --no-cache-dir --extra-index-url https://www.piwheels.org/simple --upgrade wyoming-porcupine1 && \
        deactivate
sudo ln -s /opt/Home-Satellite/systemd/wyoming-porcupine1.service /lib/systemd/user/wyoming-porcupine1.service
systemctl --user daemon-reload
systemctl --user enable --now wyoming-porcupine1.service

# Home Assistant Satellite
sudo apt -y install python3 python3-pip python3-venv alsa-utils git python3-onnx libpulse0
sudo apt -y install --no-install-recommends ffmpeg
git clone https://github.com/synesthesiam/homeassistant-satellite.git /opt/Home-Satellite/homeassistant-satellite
pushd /opt/Home-Satellite/homeassistant-satellite
script/setup
.venv/bin/pip3 install .[webrtc]
.venv/bin/pip3 install .[silerovad]
.venv/bin/pip3 install .[wyoming]
.venv/bin/pip3 install .[pulseaudio]
popd
sudo ln -s /opt/Home-Satellite/systemd/homeassistant-satellite.service /lib/systemd/user/homeassistant-satellite.service
systemctl --user daemon-reload
systemctl --user enable --now homeassistant-satellite.service

# Install Additional Utils
read -p "Install optional utils? [Y/N]" -n 1 -r
echo    # (optional) move to a new line
if [[ $REPLY =~ ^[Yy]$ ]]
then
	sudo apt -y install lsof vim apt-file locate bash-completion
	sudo apt-file update
	sudo updatedb
fi

# Configure chromium-browser auto-launch on Desktop enabled Raspberry Pi OS
read -p "Configure Chromium auto-launch? [Y/N]" -n 1 -r
echo    # (optional) move to a new line
if [[ $REPLY =~ ^[Yy]$ ]]
then
	echo "[autostart]" >> .config/wayfire.ini
	echo "chromium = chromium-browser --app='http://localhost:6680/iris' --noerrdialogs --disable-infobars --no-first-run --enable-features=OverlayScrollbar --start-maximized" >> .config/wayfire.ini
	sudo raspi-config nonint do_boot_behaviour B4
	sudo raspi-config nonint do_boot_splash 0
	sudo raspi-config nonint do_browser chromium-browser
	sudo raspi-config nonint do_blanking 0
fi

# Reboot
read -p "Reboot? [Y/N]" -n 1 -r
echo    # (optional) move to a new line
if [[ $REPLY =~ ^[Yy]$ ]]
then
	sudo reboot
fi
