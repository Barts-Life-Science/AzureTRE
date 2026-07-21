#!/bin/bash

# =============================================================================
# IMPORTANT - READ BEFORE EDITING (humans and AI tools alike):
#
# This file is NOT run directly. Terraform renders it through
# `data "template_file"` (see linuxvm.tf) BEFORE it is injected as the VM's
# custom_data / cloud-init script. It is plain-text template substitution and
# ignores shell quoting, so the rule below applies EVERYWHERE, including inside
# heredocs (quoted or not).
#
# A token of the form  dollar-sign + {NAME}  is a Terraform TEMPLATE variable,
# substituted at deploy time. ONLY names present in the template_file `vars`
# map are valid. Current keys:
#     INSTALL_UI, SHARED_STORAGE_ACCESS, STORAGE_ACCOUNT_NAME,
#     STORAGE_ACCOUNT_KEY, HTTP_ENDPOINT, FILESHARE_NAME, NEXUS_PROXY_URL,
#     CONDA_CONFIG, VM_USER
#
# Any OTHER dollar-brace (or percent-brace) token makes Terraform FAIL the
# render with "vars map does not contain key ...". You therefore CANNOT invent
# arbitrary shell variables using brace syntax - not even in a comment like this
# one (which is exactly why the examples here are spelled out in words).
#
# Safe patterns for variables you need at RUNTIME on the VM:
#   * Bare shell vars with NO braces - $HOME, $f, $(cmd), $1 - Terraform leaves
#     them alone and the shell expands them on the VM.
#   * If you genuinely need brace syntax at runtime, double the dollar sign to
#     escape it (two dollars, then the brace); the rendered script then contains
#     a single dollar plus brace token.
#   * To pass a NEW deploy-time value, add it to the `vars` map in linuxvm.tf
#     first, then reference it here.
# =============================================================================

set -o errexit
set -o pipefail
set -o nounset
# Uncomment this line to see each command for debugging (careful: this will show secrets!)
set -o xtrace

echo "init_vm.sh: START"

echo "init_vm.sh: Acquire lock"
timeout 900 bash -c -- 'while fuser /var/lib/dpkg/lock-frontend > /dev/null 2>&1
                            do
                              echo "Waiting to get lock /var/lib/dpkg/lock-frontend..."
                              sleep 5
                            done'

echo "init_vm.sh: Currently installed packages:"
apt list --installed

# Remove apt sources not included in sources.list file
echo "init_vm.sh: APT sources"
rm -f /etc/apt/sources.list.d/*

# shellcheck disable=SC1091
. /etc/os-release
sed -i "s%__VERSION_ID__%$VERSION_ID%" /etc/apt/sources.list
if [ "$VERSION_ID" == "24.04" ]; then
  echo "init_vm.sh: Fix APT for Ubuntu 24.04"
  # azuredatastudio seems to be broken, at least, that's what it reports when we run this...
  apt --fix-broken install -y

  # While we're here, disable bombing out, so we can debug this thing easier
  set +o errexit
  set +o pipefail
fi

# Update apt packages from configured Nexus sources
echo "init_vm.sh: Update OS"
export DEBIAN_FRONTEND=noninteractive
export DEBIAN_PRIORITY=critical
apt upgrade -y
apt remove -y microsoft-edge-dev || /bin/true
apt-get update -y || /bin/true # TODO Microsoft repos aren't signed properly, this gives non-zero RC.
rm -f /etc/apt/sources.list.d/* # Again, because of VS Code
apt install -y software-properties-common apt-transport-https wget dirmngr gdebi-core
# apt-get update || true

## Desktop
if [ "$VERSION_ID" == "24.04" ]; then
  echo "init_vm.sh: Desktop"

  # This next line causes problems. Force it to succeed, and hope for the best
  apt install -y xfce4 xfce4-goodies xorg dbus-x11 --fix-missing || true # --fix-missing for Ubuntu 24.04

  ## Install xrdp so Guacamole can connect via RDP
  echo "init_vm.sh: xrdp"
  apt install -y xrdp xorgxrdp xfce4-session
  adduser xrdp ssl-cert
fi
sudo -u "${VM_USER}" -i bash -c 'echo xfce4-session > ~/.xsession'
sudo -u "${VM_USER}" -i bash -c 'echo xset s off >> ~/.xsession'
sudo -u "${VM_USER}" -i bash -c 'echo xset -dpms >> ~/.xsession'

# Prevent screen timeout
echo "init_vm.sh: Preventing Timeout"
mkdir -p /home/"${VM_USER}"/.config/xfce4/xfconf/xfce-perchannel-xml
touch /home/"${VM_USER}"/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-screensaver.xml
chmod 664 /home/"${VM_USER}"/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-screensaver.xml
tee /home/"${VM_USER}"/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-screensaver.xml << END
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfce4-screensaver" version="1.0">
  <property name="saver" type="empty">
    <property name="mode" type="int" value="0"/>
    <property name="enabled" type="bool" value="false"/>
  </property>
  <property name="lock" type="empty">
    <property name="enabled" type="bool" value="false"/>
  </property>
</ channel>
END
chown -Rf "${VM_USER}":"${VM_USER}" /home/"${VM_USER}"/.config

if [ "${SHARED_STORAGE_ACCESS}" -eq 1 ]; then
  # Install required packages
  echo "init_vm.sh: Shared storage"
  apt-get install -y autofs

  # Pass in required variables
  storageAccountName="${STORAGE_ACCOUNT_NAME}"
  storageAccountKey="${STORAGE_ACCOUNT_KEY}"
  httpEndpoint="${HTTP_ENDPOINT}"
  fileShareName="${FILESHARE_NAME}"
  # Configure for permanent mount instead of autofs
  mntRoot="/shared-storage"
  credentialRoot="/etc/smbcredentials"

  # shellcheck disable=SC2308
  smbPath=$(echo "$httpEndpoint" | cut -c7-"$(expr length "$httpEndpoint")")$fileShareName
  smbCredentialFile="$credentialRoot/$storageAccountName.cred"

  # Create required file paths
  mkdir -p $credentialRoot
  mkdir -p $mntRoot

  ### Auto FS to persist storage
  # Create credential file
  if [ ! -f "$smbCredentialFile" ]; then
      echo "username=$storageAccountName" | tee "$smbCredentialFile" > /dev/null
      echo "password=$storageAccountKey" | tee -a "$smbCredentialFile" > /dev/null
  else
      echo "The credential file $smbCredentialFile already exists, and was not modified."
  fi

  # Change permissions on the credential file so only root can read or modify the password file.
  chmod 600 "$smbCredentialFile"

  echo "$smbPath $mntRoot cifs rw,vers=default,dir_mode=0777,file_mode=0777,uid=1000,gid=1000,credentials=$smbCredentialFile 0 0" | tee -a /etc/fstab >/dev/null
  mount $mntRoot
fi

## Python 3.8 and Jupyter
echo "init_vm.sh: Jupyter"
apt install -y jupyter-notebook

# R config
echo -e "local({\n    r <- getOption(\"repos\")\n    r[\"Nexus\"] <- \"${NEXUS_PROXY_URL}/repository/r-proxy/\"\n    options(repos = r)\n})" | tee /etc/R/Rprofile.site

### Anaconda Config
if [ "${CONDA_CONFIG}" -eq 1 ]; then

  # Distinguish Miniconda from the (deprecated) Anaconda layout. Validated: the 2026-04
  # images ship Miniconda at /opt/miniconda, so write channel config to its .condarc.
  if [ -d /opt/miniconda ]; then
    echo "init_vm.sh: Miniconda"
    cat <<EOF >/opt/miniconda/.condarc
channels:
  - "${NEXUS_PROXY_URL}/repository/conda-repo/main/"
  - "${NEXUS_PROXY_URL}/repository/conda-mirror/main/"
custom_channels:
    conda-forge: ${NEXUS_PROXY_URL}/repository/conda-mirror/
    bioconda: ${NEXUS_PROXY_URL}/repository/conda-mirror/
    defaults: ${NEXUS_PROXY_URL}/repository/conda-mirror/
EOF
  fi
  if [ -d "/anaconda" ]; then # Deprecated legacy Anaconda path, superseded by Miniconda.
    echo "init_vm.sh: Anaconda"
    export PATH="/anaconda/condabin:/anaconda/bin:$/anaconda/envs/py38_default/bin":$PATH
  fi
  if [ -d "/opt/anaconda" ]; then
    echo "init_vm.sh: Anaconda 2"
    export PATH="/opt/anaconda/condabin:/opt/anaconda/bin":$PATH
    which conda
    set +o errexit # Don't exit on error if one of these fails
    conda config --add channels "${NEXUS_PROXY_URL}"/repository/conda-mirror/main/ --system
    conda config --add channels "${NEXUS_PROXY_URL}"/repository/conda-repo/main/ --system
    conda config --remove channels defaults --system
    conda config --set channel_alias "${NEXUS_PROXY_URL}"/repository/conda-mirror/ --system

    for repo in $(conda config --show-sources | grep repo.anaconda.com | sort | uniq | awk '{ print $NF }')
    do
      echo "Remove $repo from global config"
      conda config --remove channels $repo --system
    done
    set -o errexit
  fi
fi

# Docker install and config
echo "init_vm.sh: Docker"
apt-get remove -y moby-tini || true
apt-get install -y ca-certificates curl gnupg lsb-release
apt-get install -y docker-compose-plugin docker-ce-cli containerd.io jq
apt-get install -y docker-ce
jq -n --arg proxy "${NEXUS_PROXY_URL}:8083" '{"registry-mirrors": [$proxy]}' > /etc/docker/daemon.json
systemctl daemon-reload
systemctl restart docker


# Application desktop launcher metadata.
# XFCE marks .desktop files on the Desktop as "untrusted" until per-user gio metadata
# (metadata::trusted + metadata::xfce-exe-checksum) is set. That metadata lives in the
# user's gvfs store and can only be written from inside a running user session (D-Bus +
# gvfsd-metadata), which does not exist at provisioning time. So install a proper XDG
# autostart *.desktop* entry (autostart runs .desktop files, not raw scripts) that runs a
# helper on login, as the user, once the session is up.
echo "init_vm.sh: desktop metadata"

# NOTE: this file is rendered by Terraform's template_file, so ${...} is a template var
# (only keys in the vars map are valid). ${VM_USER} is a real var and is substituted here
# at deploy time. The helper below uses only bare $HOME/$f so Terraform leaves it alone
# and it evaluates at login inside the user session.
mkdir -p "/home/${VM_USER}/.config/autostart" "/home/${VM_USER}/.local/bin"
# Remove earlier non-functional attempts (a raw .sh in autostart never ran).
/bin/rm -f "/home/${VM_USER}/.config/autostart/trust-desktop-launchers.desktop" \
           "/home/${VM_USER}/.config/autostart/fix-desktop-metadata.sh"

cat > "/home/${VM_USER}/.local/bin/fix-desktop-metadata.sh" << 'EOF'
#!/bin/bash
# Give the session and gvfsd-metadata a moment to come up before touching gio metadata.
sleep 5
shopt -s nullglob
for f in "$HOME"/Desktop/*.desktop; do
  chmod +x "$f"
  gio set "$f" metadata::trusted true 2>/dev/null
  h=$(sha256sum "$f" | awk '{print $1}')
  gio set "$f" metadata::xfce-exe-checksum "$h" 2>/dev/null
done
xfdesktop --reload 2>/dev/null || true
EOF
chmod 755 "/home/${VM_USER}/.local/bin/fix-desktop-metadata.sh"

# Autostart entry. XDG autostart runs *.desktop files, not raw scripts, so this .desktop
# is what actually launches the helper at login.
cat > "/home/${VM_USER}/.config/autostart/fix-desktop-metadata.desktop" << EOF
[Desktop Entry]
Type=Application
Name=Fix desktop launcher trust
Exec=/home/${VM_USER}/.local/bin/fix-desktop-metadata.sh
OnlyShowIn=XFCE;
X-GNOME-Autostart-enabled=true
NoDisplay=true
EOF

chown -Rf "${VM_USER}":"${VM_USER}" "/home/${VM_USER}/.config" "/home/${VM_USER}/.local"

echo "init_vm.sh: odds and ends"

echo "init_vm.sh: environment"
echo "export NEXUS_PROXY_URL=${NEXUS_PROXY_URL}" > /etc/profile.d/99-nexus-proxy.sh

# Jupiter Notebook Config
[ -f /usr/share/applications/jupyter-notebook.desktop ] && sed -i -e 's/Terminal=true/Terminal=false/g' /usr/share/applications/jupyter-notebook.desktop

# Default Browser
update-alternatives --config x-www-browser

## Cleanup
echo "init_vm.sh: Cleanup & restart"
rm -f /etc/apt/sources.list.d/* # Again, because of VS Code
set +o xtrace # Avoid Python stack dump from myself
shutdown -r now
