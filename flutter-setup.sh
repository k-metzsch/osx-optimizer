#!/bin/bash

# Install Homebrew if not installed
if ! command -v brew &>/dev/null; then
  echo "Homebrew not found. Installing Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >>~/.zshrc
  eval "$(/opt/homebrew/bin/brew shellenv)"
else
  echo "Homebrew already installed!"
fi

# Install Java
brew install temurin

brew install android-commandlinetools

# Package manager for iOS
brew install cocoapods

brew install robotsandpencils/made/xcodes

# Dependencies for usbfluxd
brew install make automake autoconf libtool pkg-config gcc libimobiledevice usbmuxd

# Set ANDROID_HOME to brew installation
if ! grep -q 'ANDROID_HOME' ~/.zshenv; then
  {
    echo 'export _JAVA_OPTIONS="--enable-native-access=ALL-UNNAMED"'
    echo 'export ANDROID_HOME=/usr/local/share/android-commandlinetools'
    echo 'export ANDROID_SDK_ROOT=/usr/local/share/android-commandlinetools'
    echo 'export PATH=$PATH:$ANDROID_HOME/tools:$ANDROID_HOME/tools/bin:$ANDROID_HOME/platform-tools'
    echo 'export PATH="/usr/local/bin:$PATH"'
  } >>~/.zshrc
else
  echo "Android environment variables already present in .zshenv"
fi

if ! grep -q '/usr/local/bin' ~/.zshenv; then
else
  echo "Flutter path already present in .zshenv"
fi

source ~/.zshenv

sdkmanager --update

# Get latest of each dependency for android-sdk
LATEST_BUILD_TOOLS=$(sdkmanager --list | grep -o 'build-tools;[0-9.]\+' | sort -V | tail -n1)
LATEST_PLATFORM=$(sdkmanager --list | grep -o 'platforms;android-[0-9]\+' | sort -V | tail -n1)
LATEST_SOURCES=$(sdkmanager --list | grep -o 'sources;android-[0-9]\+' | sort -V | tail -n1)

sdkmanager "$LATEST_BUILD_TOOLS"
sdkmanager "$LATEST_PLATFORM"
sdkmanager "$LATEST_SOURCES"

# Will prompt the user to login, follow instructions on screen
xcodes install --latest

# Get the latest Xcode version from xcodes, and swtich
LATEST_XCODE_PATH=$(xcodes installed | awk -F'\t' '{print $2}' | tail -n1)
sudo xcode-select --switch "$LATEST_XCODE_PATH/Contents/Developer"
sudo xcodebuild -runFirstLaunch

brew install --cask flutter

yes | flutter doctor --android-licenses

git clone https://github.com/corellium/usbfluxd.git
cd usbfluxd

./autogen.sh
make
sudo make install

flutter doctor
