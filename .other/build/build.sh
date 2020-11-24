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
  echo "Usage: build.sh [MODE]"
  echo ""
  echo -e "\tnothing   \tbuilds the addon for retail"
  echo -e "\t-c        \tbuilds the addon for classic"
  echo -e "\t-a [x]    \tsends additionnal arguments to the packaging script"
  echo ""
  echo -e "\t--release \tpreps the toc file for release"
  echo -e "\t--dev     \tpreps the toc file for development"
}

if [ -z "$1" -o "$1" == "-c" -o "$1" == "-a" ] # if we typed nothing or '-c' or '-a'
then
  cp $addondir/*.toc . # first we save the toc file
  prepRelease # so that we can safely change the toc file to our needs

  # then we clear the old builds in the package folder
  rm -rf "$packagedir/$addonname"*

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

  # we call release.sh (renamed package.sh for convenience) with the good arguments
  if [ "$1" == "-c" ]
  then
    $packagedir/package.sh -r $(pwd)/$packagedir -d -g classic $args # classic
  else
    $packagedir/package.sh -r $(pwd)/$packagedir -d $args # retail
  fi
  cd $builddir # just in case we moved in the package script

  # finally we put back the saved toc file where it belongs
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
