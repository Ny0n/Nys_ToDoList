#!/bin/bash

# script vars
addonname="Nys_ToDoList"			# the name of the addon's toc file
packagedir="package"				# the name/path to give to the package folder
tmptagfile="TAG_EDITMSG"			# the name/path to give to a temp file used for git flow purposes
devword="WIP"						# the word used to differentiate the dev addon from the release addon. Used for the toc file and commit messages
addondirpath="../../$addonname"		# the path to the dev addon folder. Use either absolute, or relative from the location of this script

# ========================================================================== #

function usage()
{
	echo ""
	echo "Usage: build.sh [MODE]"
	echo "[MODE] can be ONE of these:"
	echo ""
	echo -e "\t[-a {args}]    \tbuild the addon locally. If any {args} are specified, they will be sent to the packaging script"
	echo ""
	echo -e "\t--release      \tprep the toc file for release"
	echo -e "\t--dev          \tprep the toc file for development"
	echo ""
	echo -e "\t--publish      \tlaunch the process to publish the current addon version. Will prompt for validation before starting"

	return 1
}

function stepmsg()
{
	echo ""
	echo "** STEP $1/$2 - $3 **"
	echo ""
	sleep 0.5
}

function errormsg()
{
	last=$?

	echo ""
	case $2 in
		"vars") echo "ERROR: $1, please check the variables at the top of the script" ;;
		*) echo "ERROR: $1" ;;
	esac
	echo ""

	return $last
}

function buildmsg()
{
	last=$?

	case $2 in
		1)
			msg="** $1 COMMAND STARTED **"
			line=$(printf "*%.0s" $(seq 1 ${#msg}))
			echo ""
			echo "$line"
			echo "$msg"
			echo "$line"
			echo ""
			;;
		2)
			msg="** $1 SUCCESSFUL **"
			line=$(printf "*%.0s" $(seq 1 ${#msg}))
			echo ""
			echo "$line"
			echo "$msg"
			echo "$line"
			echo ""
			;;
		3)
			echo ""
			echo "** /!\ $1 ERROR /!\ **"
			echo "** /!\ Check log for more information /!\ **"
			echo ""
			;;
	esac


	return $last
}

function findVersion()
{
	# find and write to {version} the addon's current version number
	version="$(grep -Pom1 "(?<=## Version: ).*" "$addondir"/*.toc)"
	test -n "$version" || errormsg "Could not find the addon's version number"
}

function prepRelease()
{
	tocNewName="$(basename "$addondir"/*.toc | sed -e "s/$devword//")"
	mv "$addondir"/*.toc "$addondir/$tocNewName" # remove any WIP in the toc's name

	sed -i "s/ $devword//" "$addondir"/*.toc # remove any WIP in the toc file
}

function prepDev()
{
	tocNewName="$(basename "$addondir"/*.toc .toc)$devword.toc"
	mv "$addondir"/*.toc "$addondir/$tocNewName" # we put WIP at the end of the toc's name

	titleCurrentValue="$(grep -Pom1 "## Title:.*" "$addondir"/*.toc)"
	sed -i "s/$titleCurrentValue/$titleCurrentValue $devword/" "$addondir"/*.toc # then we put WIP at the end of the the toc file's Title tag
}

function checkExecution()
{
	echo "Running execution checkup routine..."
	sleep 1

	# check the addon's version number (findVersion must be called beforehand)
	echo ""
	test -n "$version" || errormsg "Invalid addon version number" || return
	echo "Addon version number: $version"

	# check if we are connected to the internet
	echo ""
	curl -s https://www.google.com > /dev/null 2>&1 || errormsg "Offline" || return
	echo "Online"

	# check if we have curl
	echo ""
	curl --version || errormsg "Curl" || return

	# check if we have git
	echo ""
	git --version || errormsg "Git" || return

	# check if we have git flow initialized
	echo ""
	git flow config || errormsg "Git flow" || return

	# init branch names variables
	mainbranch=$(git config --get "gitflow.branch.master")
	devbranch=$(git config --get "gitflow.branch.develop")
	test -n "$mainbranch" || errormsg "Could not figure out the master branch's name (git flow config)" || return
	test -n "$devbranch" || errormsg "Could not figure out the develop branch's name (git flow config)" || return

	# make sure we are on the dev branch
	echo ""
	git checkout "$devbranch" || errormsg "The develop branch needs to be checked out" || return
}

function package()
{
	function internal()
	{
		# will cancel the execution if something isn't available
		checkExecution || return

		# first we prep the toc file
		stepmsg 1 12 "Prep addon for release"
		prepRelease || return

		# do a temp commit of the changes, or the packaging script won't work
		stepmsg 2 12 "Commit temp changes to $devbranch branch"
		git add "$addondir" || return
		git commit -m "temp" || return

		stepmsg 3 12 "Check for the package directory"
		if [ ! -d "$packagedir" ]; then # if the package dir doesn't exist
			mkdir "$packagedir" || return # we create it
		fi

		# then we clear the old builds in the package folder
		stepmsg 4 12 "Empty the package directory"
		rm -rf "./${packagedir:?}/${addonname:?}"* || return

		# and we create (use) the packaging script from 'BigWigsMods/packager' on GitHub
		# (renaming the script 'package.sh' for naming consistency)
		stepmsg 5 12 "Curl the packaging script (from GitHub)"
		curl -s "https://raw.githubusercontent.com/BigWigsMods/packager/master/release.sh" > "$packagedir/package.sh" || return

		# here we get potential additional arguments to send to package.sh
		stepmsg 6 12 "Process the additional arguments"
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

		stepmsg 7 12 "Move to the package folder"
		cd "$packagedir" || return # we move the execution to the package folder

		# we call package.sh with the good arguments
		stepmsg 8 12 "Run the packaging script"
		./package.sh -r "$(pwd)" -d $args
		success=$?

		# we're done packaging, so we can delete the 'package.sh' script
		stepmsg 9 12 "Delete the packaging script"
		rm -f "package.sh"

		# undo the temp commit
		stepmsg 10 12 "Undo the last temp commit"
		git reset --soft HEAD~1 || return
		git restore --staged "$addondir" || return

		stepmsg 11 12 "Move to the build folder"
		cd "$builddir" || return # we come back to the build folder

		# and finally, we reset the toc file
		stepmsg 12 12 "Prep the addon for dev"
		prepDev || return

		return $success
	}

	buildmsg "BUILD" 1

	internal "$@" || buildmsg "BUILD" 3 || return

	echo ""
	echo "Addon packaged to \"$builddir/$packagedir/$addonname\"."
	buildmsg "BUILD" 2
}

function publish()
{
	function internal()
	{
		# will cancel the execution if something isn't available
		checkExecution || return

		stepmsg 1 11 "Start release"
		git flow release start "$version" || return

		stepmsg 2 11 "Prep addon for release"
		./build.sh --release || return

		stepmsg 3 11 "Commit changes on release branch"
		git add "$addondir" || return
		git commit -m "Push $version" || return

		stepmsg 4 11 "Create tmp file for tag message"
		echo "v$version" > "$tmptagfile" || return

		stepmsg 5 11 "Finish release"
		git flow release finish "$version" -f "$tmptagfile" || return

		stepmsg 6 11 "Delete tmp file for tag message"
		rm -f "$tmptagfile" || return

		stepmsg 7 11 "Push tags"
		git push --tags || return

		stepmsg 8 11 "Push main branch"
		git push origin "$mainbranch" || return

		stepmsg 9 11 "Prep addon for dev"
		./build.sh --dev || return

		stepmsg 10 11 "Commit changes on $devbranch branch"
		git add "$addondir" || return
		git commit -m "$devword $version+" || return

		stepmsg 11 11 "Push $devbranch branch"
		git push || return
	}

	buildmsg "PUBLISH" 1

	internal || buildmsg "PUBLISH" 3 || return

	echo ""
	echo "Version $version of $addonname has been published."
	buildmsg "PUBLISH" 2
}

# first of all, we change the local execution to be the script's folder,
# so that it works wherever we call it
cd "$(dirname "$0")" || exit

# check the script vars
test -n "$addonname" || errormsg "Invalid addon name" "vars" || exit
test -n "$packagedir" || errormsg "Invalid package directory name" "vars" || exit
test -n "$tmptagfile" || errormsg "Invalid tag file name" "vars" || exit
test -n "$devword" || errormsg "Invalid dev word" "vars" || exit
test -n "$addondirpath" || errormsg "Invalid addon directory path" "vars" || exit

# and here we prep the paths for the rest of the execution
builddir="$(pwd)"
case $addondirpath in
	/*) addondir="$addondirpath" ;; # absolute path
	*) addondir="$builddir/$addondirpath" ;; # relative path
esac
test -d "$builddir" -a -d "$addondir" || errormsg "Invalid directories" "vars" || exit

if [ -z "$1" ] || [ "$1" == "-a" ]; then # if we typed nothing or '-a'
	# PACKAGE COMMAND

	findVersion || exit

	read -p "$(echo -e "Package $addonname locally? (y/N) ")" -n 1 -r
	echo ""
	if [[ $REPLY =~ ^[Yy]$ ]]
	then
		package "$@"
	fi
elif [ "$1" == "--publish" ]; then
	# PUBLISH COMMAND

	findVersion || exit

	read -p "$(echo -e "\e[1mPublish\e[0m $addonname for version \e[4m$version\e[0m ? (y/N) ")" -n 1 -r
	echo ""
	if [[ $REPLY =~ ^[Yy]$ ]]
	then
		publish "$@"
	fi
elif [ "$1" == "--release" ] || [ "$1" == "--dev" ]; then
	# PREP COMMAND

	prepRelease
	if [ "$1" == "--dev" ]; then # if we want to prep for dev, we put back the WIPs
		prepDev
	fi
else
	# we misstyped something, or we typed "--help"
	usage
fi

exit
