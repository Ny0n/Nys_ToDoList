#!/bin/bash

# -- helpers --
# grep -Po 'match\K.*' file --> returns everything after match for the rest of the line
# grep -Po 'match\K[^ ]+' file --> returns the first expression after match for the rest of the line
# interface=${interface//\\/\\\\}
# interface=${interface//\*/\\*}
# interface=${interface//\//\\/}
# interface=${interface//[/\\[}
# -------------

shopt -s extglob
buildAddon()
{
  # here we get the build version (retail/classic)
  if [ -z "$1" ]
  then
    buildAddon retail
    buildAddon classic
    return
  else
    version=$1
  fi

  # first, we change some values inside of the toc file depending on the version we're building
  interfaceCurrentValue=$(grep -Pom1 "$interfacePrefix.*" ../*.toc)
  interfaceNumber=$(grep -Pom1 "$version \K.*" interfaceversions.txt)
  sed -i "s/$interfaceCurrentValue/$interfacePrefix $interfaceNumber # _$version\_/" ../*.toc # interface number

  # here we get the zip name that we'll create
  zipname="$name-$versionValue"
  if [ "$version" == "classic" ]
  then
    zipname="$zipname"_"$version"
  fi

  # here we delete any build folder/zip that already exists
  rm -rf $zipname*.zip $zipname*;

  # then we create the base folder that has the addon name, and put everyone of the addon's files in it
  mkdir $name
  ignore=$(cat buildignore.txt)
  cp -r "../"!($ignore) $name

  # then we zip
  C:/Program\ Files/7-Zip/7z.exe a -tzip -bso0 -bsp0 $zipname.zip $name # zip the folder
  C:/Program\ Files/7-Zip/7z.exe x -bso0 -bsp0 $zipname.zip -o$zipname # unzip the new zip to have an easy access to the addon, to a subfolder with the same name of the zip so that it's clearer
  rm -rf $name # then we can delete the original build folder
}

if [ ! -z "$1" -a "$1" != "--retail" -a "$1" != "--classic" ] # if we misstyped the argument
then
  echo "Usage: build.sh [VERSION]"
  echo -e "\tnothing \tbuilds the addon for retail and classic"
  echo -e "\t--retail \tbuilds the addon for retail"
  echo -e "\t--classic \tbuilds the addon for classic"
else # let's gooo
  # variables
  interfacePrefix="## Interface:"
  versionPrefix="## Version:"

  # first of all, we change the local execution to be the script's folder,
  # so that it works wherever we call it
  cd $(dirname $0)

  # we save the WIP toc file
  cp ../*.toc .
  # and remove any 'WIP' in the original's name and file
  tocNewName=$(basename ../*.toc) | sed -e "s/WIP//"
  mv ../*.toc ../$tocNewName # remove any WIP in the toc's name
  sed -i "s/WIP//" ../*.toc # remove any WIP in the toc file
  name=$(basename ../*.toc .toc)

  versionValue=$(grep -Pom1 "$versionPrefix \K.*" ../*.toc)

  buildAddon $(echo $1 | sed -e "s/--//")

  # and we put back the untouched toc file where it belongs
  rm -f ../*.toc
  mv *.toc ../
fi
shopt -u extglob
