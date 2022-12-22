#!/bin/bash

# first of all, we change the local execution to be the script's folder,
# so that it works wherever we call it
cd "$(dirname "$0")" || exit

addonname="Nys_ToDoList"
# and here we prep the paths for the rest of the execution
addondir="../../$addonname"
builddir="$(pwd)"
packagedir="package"

prepRelease()
{
	tocNewName="$(basename "$addondir"/*.toc | sed -e "s/WIP//")"
	mv "$addondir"/*.toc "$addondir/$tocNewName" # remove any WIP in the toc's name

	sed -i "s/ WIP//" "$addondir"/*.toc # remove any WIP in the toc file
}

prepDev()
{
	tocNewName="$(basename "$addondir"/*.toc .toc)WIP.toc"
	mv "$addondir"/*.toc "$addondir/$tocNewName" # we put WIP at the end of the toc's name

	titleCurrentValue="$(grep -Pom1 "## Title:.*" "$addondir"/*.toc)"
	sed -i "s/$titleCurrentValue/$titleCurrentValue WIP/" "$addondir"/*.toc # then we put WIP at the end of the the toc file's Title tag
}

usage()
{
	echo ""
	echo "Usage: build.sh [MODE]"
	echo "[MODE] can be ONE of these, with [-a {args}] meaning that we can send more arguments to the packaging script if wanted:"
	echo ""
	echo -e "\t[-a {args}]    \tbuilds the addon"
	echo ""
	echo -e "\t--release      \tpreps the toc file for release"
	echo -e "\t--dev          \tpreps the toc file for development"
}

if [ -z "$1" ] || [ "$1" == "-a" ]; then # if we typed nothing or '-a'
	# first we prep the toc file
	prepRelease
	git add "$addondir"
	git commit -m "temp"

	if [ ! -d "$packagedir" ]; then # if the package dir doesn't exist
		mkdir "$packagedir" # we create it
	fi

	# then we clear the old builds in the package folder
	rm -rf "./${packagedir:?}/${addonname:?}"*

	# and we create (use) the packaging script from 'BigWigsMods/packager' on GitHub
	# (renaming the script 'package.sh' for naming consistency)
	curl -s "https://raw.githubusercontent.com/BigWigsMods/packager/master/release.sh" > "$packagedir/package.sh"

	# here we get potential additional arguments to send to package.sh
	args=""
	mark="0"
	for i in "$@"; do
		if [ "$mark" == "1" ]; then
			if [ -z "$args" ]; then
				args="$i"
			else
				args="$args $i"
			fi
		fi
		if [ "$i" == "-a" ] && [ "$mark" == "0" ]; then
			mark="1"
		fi
	done
	if [ -z "$args" ]; then
		echo "No additional arguments"
	else
		echo "Additional arguments: \"$args\""
	fi

	cd "$packagedir" || exit # we move the execution to the package folder

	# we call package.sh with the good arguments
	./package.sh -r "$(pwd)" -d $args

	cd "$builddir" || exit # we come back to the build folder

	# we're done packaging, so we can delete the 'package.sh' script inside the package folder
	rm -f "$packagedir/package.sh"

	# and finally, we reset the toc file
	git reset --soft HEAD~1
	git restore --staged "$addondir"
	prepDev
elif [ "$1" == "--release" ] || [ "$1" == "--dev" ]; then # prep functionality
	prepRelease
	if [ "$1" == "--dev" ]; then # if we want to prep for dev, we put back the WIPs
		prepDev
	fi
else # we misstyped something
	usage
fi

exit 0
