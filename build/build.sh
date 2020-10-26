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
    buildAddon retail all
    buildAddon classic all
    return
  else
    version=$1

    # here we delete any build folder/zip that already exists before beginning
    if [ "$2" == "all" ]
    then
      rm -rf *_$version.zip *_$version/
    else
      rm -rf *_retail.zip *_retail/
      rm -rf *_classic.zip *_classic/
    fi
  fi

  # first, we change some values inside of the toc file depending on the version we're building
  interfaceCurrentValue=$(grep -Pom1 "$interfacePrefix.*" ../*.toc)
  interfaceNumber=$(grep -Pom1 "## X-Interface-$version: \K.*" ../*.toc)
  sed -i "s/$interfaceCurrentValue/$interfacePrefix $interfaceNumber/" ../*.toc # interface number

  wowVersionCurrentValue=$(grep -Pom1 "$wowVersionPrefix.*" ../*.toc)
  sed -i "s/$wowVersionCurrentValue/$wowVersionPrefix $version/" ../*.toc # interface number

  # then we create the base folder that has the addon name, and put everyone of the addon's files in it
  mkdir $name
  ignore=$(cat buildignore.txt)
  cp -r "../"!($ignore) $name

  # then we zip
  zipname="$name-$versionValue"_"$version" # zip name
  C:/Program\ Files/7-Zip/7z.exe a -tzip -bso0 -bsp0 $zipname.zip $name # zip the folder
  C:/Program\ Files/7-Zip/7z.exe x -bso0 -bsp0 $zipname.zip -o$zipname # unzip the new zip to have an easy access to the addon, to a subfolder with the same name of the zip so that it's clearer
  rm -rf $name # then we can delete the original build folder
}

prepRelease()
{
  tocNewName=$(echo $(basename ../*.toc) | sed -e "s/WIP//")
  mv ../*.toc ../$tocNewName # remove any WIP in the toc's name
  sed -i "s/ WIP//" ../*.toc # remove any WIP in the toc file
}

prepDev()
{
  tocNewName=$(echo $(basename ../*.toc .toc)WIP.toc)
  mv ../*.toc ../$tocNewName # we put WIP at the end of the toc's name

  titleCurrentValue=$(grep -Pom1 "## Title:.*" ../*.toc)
  sed -i "s/$titleCurrentValue/$titleCurrentValue WIP/" ../*.toc # then we put WIP in the Title
}

# first of all, we change the local execution to be the script's folder,
# so that it works wherever we call it
cd $(dirname $0)

if [ ! -z "$1" -a "$1" != "--retail" -a "$1" != "--classic" -a "$1" != "--release" -a "$1" != "--dev" ] # if we misstyped the argument
then
  echo "Usage: build.sh [MODE]"
  echo ""
  echo -e "\tnothing   \tbuilds the addon for retail and classic"
  echo -e "\t--retail  \tbuilds the addon for retail"
  echo -e "\t--classic \tbuilds the addon for classic"
  echo ""
  echo -e "\t--release \tpreps the toc file for release"
  echo -e "\t--dev     \tpreps the toc file for development"
elif [ "$1" == "--release" -o "$1" == "--dev" ] # prep functionnality
then
  prepRelease
  if [ "$1" == "--dev" ] # if we want to prep for dev, we put back the WIPs
  then
    prepDev
  fi
else # let's gooo
  cp ../*.toc . # first we save the toc file
  prepRelease # so that we can safely change the toc file to our needs

  # we prepare some variables
  name=$(basename ../*.toc .toc) # here we have the pure addon name
  interfacePrefix="## Interface:"
  wowVersionPrefix="## X-WoW-Version:"
  versionValue=$(grep -Pom1 "## Version: \K.*" ../*.toc)

  # boom
  buildAddon $(echo $1 | sed -e "s/--//")

  # finally we put back the saved toc file where it belongs
  rm -f ../*.toc
  mv *.toc ../
fi
shopt -u extglob
