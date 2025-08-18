#!/usr/bin/env bash

# Ensure macOS
if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "This script must run on macOS."
  exit 1
fi

# Elevate privileges
if [[ $EUID -ne 0 ]]; then
  echo "Requesting sudo privileges..."
  sudo -v
  while true; do
    sudo -n true
    sleep 60
    kill -0 "$$" || exit
  done 2>/dev/null &
fi

read -rp "Enable auto-login? [y/N]: " REPLY_ENABLE
REPLY_ENABLE="${REPLY_ENABLE:-N}"

ENABLE_AUTOLOGIN="false"

if [[ "$REPLY_ENABLE" =~ ^[Yy] ]]; then
  echo "Auto-login will be enabled."
  ENABLE_AUTOLOGIN="true"
else
  echo "Auto-login will NOT be enabled."
fi

TARGET_USER=""
AUTOLOGIN_PASS=""

if [[ "$ENABLE_AUTOLOGIN" == "true" ]]; then
  while [[ -z "${TARGET_USER}" ]]; do
    read -rp "Enter the macOS short username for auto-login: " TARGET_USER
  done

  if ! id "$TARGET_USER" >/dev/null 2>&1; then
    echo "User '$TARGET_USER' does not exist. Create it first and re-run."
    exit 1
  fi

  while [[ -z "${AUTOLOGIN_PASS}" ]]; do
    read -srp "Enter password for user '$TARGET_USER': " AUTOLOGIN_PASS
    echo
    read -srp "Re-enter password to confirm: " AUTOLOGIN_PASS_CONFIRM
    echo
    if [[ "$AUTOLOGIN_PASS" != "$AUTOLOGIN_PASS_CONFIRM" ]]; then
      echo "Passwords do not match. Try again."
      AUTOLOGIN_PASS=""
    fi
  done
fi

create_kcpassword() {
  # Apple XOR obfuscation
  local pass="$1"
  local key=(0x7d 0x89 0x52 0x23 0xd2 0xbc 0xdd 0xf8)
  pass+=$'\0'
  local hexstream=""
  for ((i = 0; i < ${#pass}; i++)); do
    local c="${pass:i:1}"
    local dec
    dec=$(printf "%d" "'$c")
    local k=${key[$((i % ${#key[@]}))]}
    local xor=$((dec ^ k))
    hexstream+="\\x$(printf "%02x" "$xor")"
  done
  printf '%b' "$hexstream" >/etc/kcpassword
  chown root:wheel /etc/kcpassword
  chmod 600 /etc/kcpassword
}

if [[ "$ENABLE_AUTOLOGIN" == "true" ]]; then
  echo "Enabling auto-login for user: $TARGET_USER"
  defaults write /Library/Preferences/com.apple.loginwindow autoLoginUser -string "$TARGET_USER"
  create_kcpassword "$AUTOLOGIN_PASS"
else
  echo "Auto-login will NOT be enabled."
fi

echo "Disabling Spotlight indexing"
mdutil -i off -a || true # Spotlight may already be disabled; ignoring error

echo "Adjusting NVRAM boot-args"
if /usr/sbin/nvram boot-args >/dev/null 2>&1; then
  CURRENT="$(/usr/sbin/nvram boot-args 2>/dev/null | sed -e $'s/boot-args\t//')"
  CLEANED="$(echo "$CURRENT" | sed 's/serverperfmode=1//g' | tr -s ' ' | sed 's/^ *//;s/ *$//')"

  if [[ "$CURRENT" != "$CLEANED" ]]; then
    if [[ -z "$CLEANED" ]]; then
      /usr/sbin/nvram -d boot-args
    else
      /usr/sbin/nvram boot-args="$CLEANED"
    fi
  fi
fi

echo "Setting blank login window desktop picture"
defaults write /Library/Preferences/com.apple.loginwindow DesktopPicture -string ""

echo "Applying UI tweaks"
defaults write com.apple.Accessibility DifferentiateWithoutColor -int 1
defaults write com.apple.Accessibility ReduceMotionEnabled -int 1
defaults write com.apple.universalaccess reduceMotion -int 1
defaults write com.apple.universalaccess reduceTransparency -int 1

echo "Enabling multiple sessions"
/usr/bin/defaults write .GlobalPreferences MultipleSessionsEnabled -bool true
defaults write 'Apple Global Domain' MultipleSessionsEnabled -bool true

echo "Disabling automatic updates"
defaults write /Library/Preferences/com.apple.SoftwareUpdate AutomaticDownload -bool false
defaults write /Library/Preferences/com.apple.SoftwareUpdate AutomaticCheckEnabled -bool false
defaults write /Library/Preferences/com.apple.SoftwareUpdate ConfigDataInstall -int 0
defaults write /Library/Preferences/com.apple.SoftwareUpdate CriticalUpdateInstall -int 0
defaults write /Library/Preferences/com.apple.SoftwareUpdate ScheduleFrequency -int 0
defaults write /Library/Preferences/com.apple.SoftwareUpdate AutomaticDownload -int 0
defaults write /Library/Preferences/com.apple.commerce AutoUpdate -bool false
defaults write /Library/Preferences/com.apple.commerce AutoUpdateRestartRequired -bool false

echo "Setting universalaccessAuthWarning keys"
defaults write com.apple.universalaccessAuthWarning /System/Applications/Utilities/Terminal.app -bool true
defaults write com.apple.universalaccessAuthWarning /usr/libexec -bool true
defaults write com.apple.universalaccessAuthWarning /usr/libexec/sshd-keygen-wrapper -bool true
defaults write com.apple.universalaccessAuthWarning com.apple.Messages -bool true
defaults write com.apple.universalaccessAuthWarning com.apple.Terminal -bool true

echo "Disabling screen lock"
defaults write com.apple.loginwindow DisableScreenLock -bool true

echo "Setting wildcard AllowList"
defaults write com.apple.loginwindow AllowList -string '*'

echo "Disabling logout state save"
defaults write com.apple.loginwindow TALLogoutSavesState -bool false

echo "Configuring RemoteManagement"
/System/Library/CoreServices/RemoteManagement/ARDAgent.app/Contents/Resources/kickstart \
  -activate -configure -access -off -restart -agent -privs -all -allowAccessFor -allUsers

if [[ "$ENABLE_AUTOLOGIN" == "true" ]]; then
  echo "Disabling App Sleep globally for auto-login user..."
  sudo -u "$TARGET_USER" defaults write NSGlobalDomain NSAppSleepDisabled -bool YES
fi

echo "System tweaks applied. A reboot may be required for some settings"

read -rp "Reboot system now? [Y/n]: " REPLY_REBOOT
REPLY_REBOOT="${REPLY_REBOOT:-Y}"

if [[ "$REPLY_REBOOT" =~ ^[Yy] ]]; then
  sudo reboot
fi
