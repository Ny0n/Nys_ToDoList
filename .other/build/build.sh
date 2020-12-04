#!/bin/bash

# first of all, we change the local execution to be the script's folder,
# so that it works wherever we call it
cd $(dirname $0)

addonname="Nys_ToDoList"
# and here we prep the paths for the rest of the execution
addondir="../../$addonname"
builddir=$(pwd)
packagedir="package"

prepRelease()
{
  tocNewName=$(echo $(basename $addondir/*.toc) | sed -e "s/WIP//")
  mv $addondir/*.toc $addondir/$tocNewName # remove any WIP in the toc's name

  sed -i "s/ WIP//" $addondir/*.toc # remove any WIP in the toc file
}

prepDev()
{
  tocNewName=$(echo $(basename $addondir/*.toc .toc)WIP.toc)
  mv $addondir/*.toc $addondir/$tocNewName # we put WIP at the end of the toc's name

  titleCurrentValue=$(grep -Pom1 "## Title:.*" $addondir/*.toc)
  sed -i "s/$titleCurrentValue/$titleCurrentValue WIP/" $addondir/*.toc # then we put WIP at the end of the the toc file's Title tag
}

usage()
{
  echo ""
  echo "Usage: build.sh [MODE]"
  echo "[MODE] can be ONE of these, with [-a {args}] meaning that we can send more arguments to the packaging script if wanted:"
  echo ""
  echo -e "\t[-a {args}]    \tbuilds the addon for retail"
  echo -e "\t-c [-a {args}] \tbuilds the addon for classic"
  echo ""
  echo -e "\t--release      \tpreps the toc file for release"
  echo -e "\t--dev          \tpreps the toc file for development"
}

if [ -z "$1" -o "$1" == "-c" -o "$1" == "-a" ] # if we typed nothing or '-c' or '-a'
then
  cp $addondir/*.toc . # first we save the toc file
  prepRelease # so that we can safely change the toc file to our needs

  if [ ! -d "$packagedir" ] # if the package dir doesn't exists
  then
    mkdir "$packagedir" # then we create it
  fi

  # then we clear the old builds in the package folder
  rm -rf "$packagedir/$addonname"*

  # and we create (use) the packaging script from 'BigWigsMods/packager' on github
  curl -s "https://raw.githubusercontent.com/BigWigsMods/packager/e29ee19573d8e5490572b67f006eb5337b5a4436/release.sh" > "$packagedir/package.sh"
  # i voluntarily used a specific commit and not the latest master vesion,
  # because i need to add a line of code inside the script at a specific point,
  # and i need consistency to do that, so i'm sure that the curl always gives me the same script
  sed -i '1380i\\t\t\t\tif [ $(basename "$file") == "Nys_ToDoList.toc" ]; then skip_copy=; fi' "$packagedir/package.sh"

  # here we get potential additionnal arguments to send to package.sh
  args=""
  mark="0"
  for i in "$@"
  do
    if [ "$mark" == "1" ]; then
      args="$args $i"
    fi
    if [ "$i" == "-a" -a "$mark" == "0" ]; then
      mark="1"
    fi
  done

  cd $packagedir # we move the execution to the package folder
  # we call release.sh (renamed package.sh for naming consistency :D) with the good arguments
  if [ "$1" == "-c" ]
  then
    ./package.sh -r $(pwd) -d -g classic $args # classic
  else
    ./package.sh -r $(pwd) -d $args # retail
  fi
  cd $builddir # we come back to the build folder

  # we're done packaging, so we can delete the 'package.sh' script inside the package folder
  rm -f "$packagedir/package.sh"

  # and finally, we put back the saved toc file where it belongs
  rm -f $addondir/*.toc
  mv *.toc $addondir/
elif [ "$1" == "--release" -o "$1" == "--dev" ] # prep functionnality
then
  prepRelease
  if [ "$1" == "--dev" ] # if we want to prep for dev, we put back the WIPs
  then
    prepDev
  fi
else # we misstyped something
  usage
fi

exit 0
