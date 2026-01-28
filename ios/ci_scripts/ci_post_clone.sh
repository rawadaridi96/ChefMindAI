#!/bin/sh

# The default execution directory of this script is the ci_scripts directory.
# Traverse up the directory tree to find the root of the repository.
cd "$(dirname "$0")/../../"

# Install Flutter
echo "Installing Flutter..."
git clone https://github.com/flutter/flutter.git --depth 1 -b stable $HOME/flutter
export PATH="$PATH:$HOME/flutter/bin"

# Install CocoaPods
echo "Installing CocoaPods..."
sudo gem install cocoapods

# Install Flutter dependencies
echo "Running flutter pub get..."
flutter pub get

# Install iOS dependencies
echo "Installing iOS dependencies..."
cd ios
pod install
