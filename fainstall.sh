#!/bin/bash
# Copyright (C) 2014 ClearCode Inc.

echo "Fx Meta Installer (easy edition)"

# ================================================================
# Initialize self
# ================================================================

fainstall_ini="./fainstall.ini"

resources="."
if [ -d "./resources" ]; then resources="./resources"; fi

application="$1"
if [ -f "$resources/Firefox-setup.ini" -o -f "$resources/Firefox-setup.exe" ]
then
  application="firefox"
fi
if [ -f "$resources/Thunderbird-setup.ini" -o -f "$resources/Thunderbird-setup.exe" ]
then
  application="thunderbird"
fi
application=$(echo "$application" | tr "[A-Z]" "[a-z]")


if [ "$1" = "--help" -o "$application" = "" ]
then
  echo ""
  echo "Usage:"
  echo "  ./fainstall.sh APPNAME"
  echo ""
  echo "The argument APPNAME is the target application."
  echo "Possible values:"
  echo " - \"firefox\""
  echo " - \"thunderbird\""
  exit 0
fi


DRY_RUN=yes

try_run() {
  if [ "$DRY_RUN" = "yes" ]
  then
    echo "> Run: $@"
  else
    exec "$@"
  fi
}

case $(uname) in
  Darwin|*BSD) sed="sed -E" ;;
  *)           sed="sed -r" ;;
esac


# ================================================================
# Check required commands
# ================================================================

if [ ! -f "$(which unzip)" ]
then
  echo "ERROR: Required command \"unzip\" is not available."
  exit 1
fi


# ================================================================
# Initialize variables
# ================================================================

detect_application_dir() {
  local application=$1
  possible_application_dirs="/usr/lib64/$application /usr/lib/$application"
  for location in $possible_application_dirs
  do
    if [ -d "$location" -a -f "$location/$application" ]
    then
      echo "$location"
      return 0
    fi
  done
  echo ""
  return 0
}
application_dir=$(detect_application_dir "$application")

echo "Target Application: $application"
echo "Target Location:    $application_dir"
echo ""

if [ "$application_dir" = "" ]
then
  echo "ERROR: The target location is not found."
  exit 1
fi

if [ ! -d "$application_dir" ]
then
  echo "ERROR: The target location does not exist."
  exit 1
fi




# ================================================================
# Installation
# ================================================================


# Enable/disable crash report

# Update existing shortcuts (not implemented)

# Set default client / disable client (not implemented)

# Install custom profiles (not implemented)


# ================================================================
# Install additional files
# ================================================================

install_files() {
  local target_location=$1
  local files=$2
  local option=$3

  find $resources -name "$files" | while read file
  do
    if [ -f "$file" ]
    then
      if [ ! -d "$target_location" -a "$option" = "create" ]
      then
        echo "Creating directory: $target_location"
        try_run mkdir -p "$target_location"
        try_run chown root:root "$target_location"
        try_run chmod 755 "$target_location"
      fi

      if [ ! -d "$target_location" ]; then return 0; fi

      echo "Installing file: $file => $target_location/"
      try_run cp "$file" "$target_location/"
      installed_file="$target_location/$(basename "$file")"
      try_run chown root:root "$installed_file"
      try_run chmod 644 "$installed_file"
    fi
  done
}

install_files "$application_dir" "*.cfg"
install_files "$application_dir" "*.properties"
install_files "$application_dir" "override.ini"

install_files "$application_dir/defaults" "*.cer"
install_files "$application_dir/defaults" "*.crt"
install_files "$application_dir/defaults" "*.pem"
install_files "$application_dir/defaults" "*.cer.override"
install_files "$application_dir/defaults" "*.crt.override"
install_files "$application_dir/defaults" "*.pem.override"

install_files "$application_dir/defaults/profile" "bookmarks.html" "create"
install_files "$application_dir/defaults/profile" "*.rdf" "create"

install_files "$application_dir/isp" "*.xml" "create"

install_files "$application_dir/defaults/pref" "*.js"
install_files "$application_dir/defaults/preferences" "*.js"

install_files "$application_dir/chrome" "*.css"
install_files "$application_dir/chrome" "*.jar"
install_files "$application_dir/chrome" "*.manifest"

install_files "$application_dir/components" "*.xpt"

## Install *.dll => appdir/plugins/ (not implemented)

install_files "$application_dir/distribution" "distribution.*" "create"

## for Firefox
install_files "$application_dir/browser" "override.ini"
install_files "$application_dir/browser/defaults/profile" "bookmarks.html"
install_files "$target_location/browser/defaults/profile" "*.rdf"
### Install *.dll => appdir/browser/plugins/ (not implemented)

## for Netscape
### Install installed-chrome.txt => appdir/ (not implemented)

## Install *.lnk => desktop/ (not implemented)


# ================================================================
# Install addons
# ================================================================

install_addon() {
  local file=$1

  local basename=$(basename "$file")
  local tmpdir="/tmp/$basename"

  rm -rf "$tmpdir"
  mkdir -p "$tmpdir"
  unzip "$file" -d "$tmpdir" > /dev/null

  local id=$(grep "em:id" "$tmpdir/install.rdf" | head -n 1 | \
               $sed -e "s/ *<[^>]+> *//g" \
                    -e "s/[^=]+= *\"([^\"]+)\"/\1/" \
                    -e "s/[^=]+= *'([^\"]+)'/\1/" | \
               tr -d "\r" | tr -d "\n")
  local target_location=$(get_addon_install_location "$file" "$id")

  echo "Installing addon: $basename => $target_location"

  try_run rm -rf "$target_location"
  try_run mkdir -p "$target_location"
  try_run mv "$tmpdir/*" "$target_location/"
  rm -rf "$tmpdir"
}

get_addon_install_location() {
  local file=$1
  local basename=$(basename "$1")
  local id=$2

  if [ -f "$fainstall_ini" ]
  then
    local id_from_ini=$(grep --after-context=5 "\[$basename\]" "$fainstall_ini" | \
                          grep "AddonId=" | head -n 1 | cut -d "=" -f 2 | \
                          tr -d "\r" | tr -d "\n")
    if [ "$id_from_ini" != "" ]
    then
      local id="$id_from_ini"
    fi

    local target_location=$(grep --after-context=5 "\[$basename\]" "$fainstall_ini" | \
                              grep "TargetLocation=" | head -n 1 | cut -d "=" -f 2 | \
                              $sed -e 's#\\#/#g' | tr -d "\r" | tr -d "\n" )
    local target_location=$(resolve_place_holders "$target_location")
    if [ "$target_location" != "" ]
    then
      echo "$target_location/$id"
      return 0
    fi
  fi

  echo "$application_dir/distribution/bundles/$id"
  return 0
}

resolve_place_holders() {
  echo "$1" | \
    $sed -e "s;\%AppData\%;$HOME;i" \
         -e "s;\%HomePath\%;$HOME;i" \
         -e "s;\%UserName\%;$USER;i" \
         -e "s;\%Tmp\%;/tmp;i" \
         -e "s;\%Temp\%;/tmp;i" \
         -e "s;\%ComputerName\%;$(cat /etc/hostname | tr -d "\n" | tr -d "\r");i" \
         -e "s;\%Home\%;$HOME;i" \
         -e "s;\%DeskTop\%;$HOME/Desktop;i" \
         -e "s;\%AppDir\%;$application_dir;i"
         # not implemented:
         # -e "s;\%HomeDrive\%;???;i" \
         # -e "s;\%SystemDrive\%;???;i" \
         # -e "s;\%SystemRoot\%;???;i" \
         # -e "s;\%WinDir\%;???;i" \
         # -e "s;\%ProgramFiles\%;???;i" \
         # -e "s;\%CommonProgramFiles\%;???;i" \
         # -e "s;\%AllUsersProfile\%;???;i" \
         # -e "s;\%SysDir\%;???;i" \
         # -e "s;\%ProgramFiles32\%;???;i" \
         # -e "s;\%ProgramFiles64\%;???;i" \
         # -e "s;\%CommonFiles\%;???;i" \
         # -e "s;\%CommonFiles32\%;???;i" \
         # -e "s;\%CommonFiles64\%;???;i" \
         # -e "s;\%StartMenu\%;???;i" \
         # -e "s;\%Programs\%;???;i" \
  return 0
}

find $resources -name "*.xpi" | while read file
do
  install_addon "$file"
done


# Install shortcuts (not implemented)

# Run extra installers (not implemented)

# Install search plugins (not implemented)

## Install searchplugins => appdir/browser/searchplugins/ or appdir/searchplugins/ (not implemented)

## Disable searchplugins (not implemented)


echo ""
echo "Done."
exit 0
