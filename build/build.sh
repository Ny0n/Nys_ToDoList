#!/bin/bash

# first of all, we change the local execution to be the script's folder,
# so that it works wherever we call it
cd $(dirname $0)

# addon name
name='Nys_ToDoList'

# here we check if we chose to set a specific tag name
zipname=$name
if [ ! -z $1 ]
then
  zipname="$zipname-$1"
fi

# first we delete any build folder/zip that already exists
rm -rf $name *.zip; mkdir $name

# then we create the base folder that has the addon name, and put everyone of the addon's files in it
shopt -s extglob
ignore=$(cat buildignore.txt)
cp -r "../"!($ignore) $name
shopt -u extglob

# then we zip that folder
C:/Program\ Files/7-Zip/7z.exe a -tzip $zipname.zip $name
