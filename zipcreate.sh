#!/bin/bash

# addon name
name='Nys_ToDoList'
zipname=$name

# here we check if we chose to set a specific tag name
if [ ! -z $1 ]
then
  zipname="$zipname-$1"
fi

# first we delete any build folder/zip that already exists
rm -rf $name *.zip; mkdir $name

# then we create the base folder that has the addon name, and put everyone of the addon's files in it
shopt -s extglob
ignore=$(cat zipignore.txt)
cp -r !($ignore) $name

# then we zip that folder
C:/Program\ Files/7-Zip/7z.exe a -tzip $zipname.zip $name

# and we end the script by removing the folder, so there is only the zip left
shopt -u extglob
rm -rf $name
