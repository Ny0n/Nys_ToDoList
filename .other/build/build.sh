#!/bin/bash

: '

This build script is used for 3 things:
	- Package addons locally, using the latest BigWigsMods/packager/release.sh script
	- Publish addons, again using the packager script and git flow
	- Create symlinks, to setup the addon dev environment

For the Package and Publish command, the packager script will search for,
and use a ".pkgmeta" file at the source of your git repository.

The Package command will create the builds inside of the "addons_dir" folder.

The Publish command will use git flow to create a release using the "main_addon" version as a name,
it will then push it to github where the release.yml file will automatically start an action to call the packager script,
and this time it will not build locally, but create and publish a release on github and on curseforge (depending on the "X-" metadatas in the TOC file).

The Symlink command will create symlinks between the WoW addons folders, and the specified addons inside the repository ("addons_to_symlink"),
see https://github.com/WeakAuras/WeakAuras2/wiki/Lua-Dev-Environment#create-symlinks to understand what I mean.
You can also create symlinks for a common "SavedVariables" folder, that will be used to source all saved variables for every WoW version,
so you will share the same saved variables between Retail ("_retail_") and Classic ("_classic_"), as an example.

You can modify the variables just below to customize the behavior of the script.

'

# addons info

main_addon="Nys_ToDoList"                           # The name of the main addon's folder and toc file. Used to find the addon's version
addons_dir="../.."                                  # The path to the dev addon folder (usually the repository). Either absolute (/*) or relative (*)

# --local

package_dir="package"                               # (--local command) The name/path for the package folder. The script will create it if it doesn't exist. Either absolute (/*) or relative (*)

# --symlink [-d]

addons_to_symlink=()                                # Found in $addons_dir
addons_to_symlink+=("$main_addon")
addons_to_symlink+=("Nys_ToDoList_Backup")

# --symlink [-d|-f]

wow_dir="/c/Program Files (x86)/World of Warcraft"  # Only absolute (/*)

wow_versions=()                                     # Add/Remove wow versions below (used for addon & saved vars symlink locations)
wow_versions+=("_retail_")
wow_versions+=("_classic_")
wow_versions+=("_classic_era_")
wow_versions+=("_ptr_")
wow_versions+=("_ptr2_")
wow_versions+=("_beta_")

# --symlink [-f]

saved_vars_dir="$wow_dir/SavedVariables"           # Common saved vars folder path, the one we will point to for every WoW version. Either absolute (/*) or relative (*)
account_file_names=()                              # Add/Remove account file names below (used for saved vars symlink locations)
account_file_names+=("122995789#1")
account_file_names+=("122995789#2")

# ========== FUNCTIONS ================================================================ #

# ========== UTILS ========== #

function usage()
{
	cat <<-'EOF' >&2
	Usage: build.sh [MODE]

	[MODE] can be ONE of these:

	  --local [-a {args}]    Build the addon locally. If any {args} are specified, they will be sent to the packaging script.
	  --publish              Launch the process to publish the current addon version. Will prompt for validation before starting.
	  --symlink [-d|-f]      Create all addon symlinks. You can limit what gets created with -d (only addon directories) or -f (only saved variables directories).

	Example: build.sh --local -a -c
	EOF

	return 1
}

function step_msg()
{
	echo ""
	echo "** STEP $1/$2 - $3 **"
	echo ""
	sleep 0.5
}

function error_msg()
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

function build_msg()
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

function find_version()
{
	# find and write to $version the main addon's current version number
	version="$(grep -Pom1 "(?<=## Version: ).*" "$toc_file")"
	test -n "$version" || error_msg "Could not find the addon's version number"
}

# ========== PACKAGE COMMAND ========== #

function check_package_execution()
{
	echo "Running execution checkup routine..."
	sleep 1

	# check the addon's version number (find_version must be called beforehand)
	echo ""
	test -n "$version" || error_msg "Invalid addon version number" || return
	echo "Addon version number: $version"

	# check if we are connected to the internet
	echo ""
	curl -s https://www.google.com > /dev/null 2>&1 || error_msg "Offline" || return
	echo "Online"

	# check if we have curl
	echo ""
	curl --version || error_msg "Curl" || return
}

function package()
{
	function internal()
	{
		# will cancel the execution if something isn't available
		check_package_execution || return

		step_msg 1 5 "Check for the package directory"
		test -n "$package_dir" || error_msg "Invalid package directory" "vars" || return

		if [ ! -d "$package_dir" ]; then # if the package dir doesn't exist
			mkdir "$package_dir" || return # we create it
		fi

		package_dir="$(cd "$package_dir" && pwd)" # to absolute path

		test -n "$package_dir" -a -d "$package_dir" || error_msg "Invalid package directory" "vars" || return
		echo "Package directory: \"$package_dir\""

		# then we clear the old builds in the package folder
		step_msg 2 5 "Cleanup the package directory"
		rm -rf "${package_dir:?}/${main_addon:?}"* || return
		test ! -e "$package_dir/package.sh" || rm -f "$package_dir/package.sh" > /dev/null 2>&1 || error_msg "Invalid file found at \"$package_dir/package.sh\", please remove it and try again" || return

		# and we create (use) the packaging script from 'BigWigsMods/packager' on GitHub
		# (renaming the script 'package.sh' for naming consistency)
		step_msg 3 5 "Curl the packaging script (from GitHub)"
		curl -s "https://raw.githubusercontent.com/BigWigsMods/packager/master/release.sh" > "$package_dir/package.sh" || return

		# here we get potential additional arguments to send to package.sh
		step_msg 4 5 "Process the additional arguments"
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

		# we call package.sh with the good arguments
		step_msg 5 5 "Run the packaging script"
		(cd "$package_dir" || exit; ./package.sh -r "$(pwd)" -d $args) || return
	}

	build_msg "BUILD" 1

	internal "$@" || build_msg "BUILD" 3 || return

	echo ""
	echo "Addons packaged to \"$package_dir\"."
	build_msg "BUILD" 2
}

# ========== PUBLISH COMMAND ========== #

function check_publish_execution()
{
	check_package_execution || return

	# check if we have git
	echo ""
	git --version || error_msg "Git" || return

	# check if we have git flow initialized
	echo ""
	git flow config || error_msg "Git flow" || return

	# init branch names variables
	main_branch_name=$(git config --get "gitflow.branch.master")
	dev_branch_name=$(git config --get "gitflow.branch.develop")
	test -n "$main_branch_name" || error_msg "Could not figure out the master branch's name (git flow config)" || return
	test -n "$dev_branch_name" || error_msg "Could not figure out the develop branch's name (git flow config)" || return
}

function publish()
{
	function internal()
	{
		# will cancel the execution if something isn't available
		check_publish_execution || return

		# make sure we are on the dev branch
		echo ""
		test "$dev_branch_name" == "$(git branch --show-current)" || error_msg "The develop branch needs to be checked out" || return

		step_msg 1 5 "Start release"
		git flow release start "$version" || return
		echo "v$version" > "__TAG_EDITMSG" || return

		step_msg 2 5 "Finish release"
		git flow release finish "$version" -f "__TAG_EDITMSG" || return
		rm -f "__TAG_EDITMSG" || return

		step_msg 3 5 "Push tags"
		git push --tags || return

		step_msg 4 5 "Push main branch"
		git push origin "$main_branch_name" || return

		step_msg 5 5 "Push $dev_branch_name branch"
		git push || return
	}

	build_msg "PUBLISH" 1

	internal || build_msg "PUBLISH" 3 || return

	echo ""
	echo "Version $version of $main_addon has been published."
	build_msg "PUBLISH" 2
}

# ========== MAKE LINKS COMMAND ========== #

function make_links()
{
	function internal_addon_dir()
	{
		test -d "$1" || error_msg "Invalid source folder for links" "vars" || return
		test -n "$2" || error_msg "Invalid addon name for links" "vars" || return

		for version in "${wow_versions[@]}"; do
			toPath="$wow_dir/$version/Interface/AddOns" # WOW ADDON PATH
			if [ ! -d "$toPath" ]; then
				echo -e "\e[33m-\e[0m WoW \"$version\" version not found"
				continue
			fi

			to="${toPath:?}/${2:?}"
			test ! -f "$to" -a ! -d "$to" -a ! -L "$to" || rm -rf "$to"

			ln -s "$1" "$to" || return
			echo -e "\e[32m+\e[0m \"$to\" (symlink) --> (target) \"$1\""
			symlinkCount=$((symlinkCount+1))
		done
	}

	function internal_saved_dir()
	{
		test -d "$1" || error_msg "Invalid source folder for saved variables links" "vars" || return

		for version in "${wow_versions[@]}"; do
			toPath="$wow_dir/$version/WTF/Account" # WOW SAVED VARIABLES PATH
			if [ ! -d "$toPath" ]; then
				echo -e "\e[33m-\e[0m WoW \"$version\" version not found"
				continue
			fi

			for account in "${account_file_names[@]}"; do
				toPathAccount="$toPath/$account" # WOW SAVED VARIABLES PATH
				if [ ! -d "$toPathAccount" ] || [ -z "$account" ]; then
					echo -e "\e[33m-\e[0m Account \"$account\" not found for \"$version\""
					continue
				fi

				to="${toPathAccount:?}/SavedVariables"
				if [ -d "$to" ]; then
					if [ ! -L "$to" ] && [ -n "$(ls -A "$to")" ]; then
						echo -e "\e[31m-\e[0m Found a non-empty SavedVariables directory, skipping. Please backup, remove the folder and try again (\"$to\")"
						continue
					fi
					rm -rf "$to"
				fi

				ln -s "$1" "$to" || return
				echo -e "\e[32m+\e[0m \"$to\" (symlink) --> (target) \"$1\""
				symlinkCount=$((symlinkCount+1))
			done
		done
	}

	# === check all variables and paths === #

	test -z "$1" || test "$1" == "-d"
	can_do_dir=$?

	test -z "$1" || test "$1" == "-f"
	can_do_saved_dir=$?

	if [ "$can_do_dir" -ne 0 ] && [ "$can_do_saved_dir" -ne 0 ]; then
		usage
		return
	fi

	ln --version || error_msg "The \"ln\" command must be installed to create symbolic links" || return
	export MSYS=winsymlinks:nativestrict || return # to create real symlinks with ln, not just copies

	test -n "$wow_dir" -a -d "$wow_dir" || error_msg "Invalid WoW directory" "vars" || return
	test "${#wow_versions[@]}" -ne 0 || error_msg "No WoW version has been specified" "vars" || return

	# if [ "$can_do_dir" -eq 0 ]; then
		# $addons_dir has already been verified
	# fi

	if [ "$can_do_saved_dir" -eq 0 ]; then
		test "${#account_file_names[@]}" -ne 0 || error_msg "No account file name has been specified" "vars" || return

		test -n "$saved_vars_dir" || error_msg "Invalid saved vars directory" "vars" || return
		saved_vars_dir="$(cd "$saved_vars_dir" && pwd)" # to absolute path
		test -n "$saved_vars_dir" -a -d "$saved_vars_dir" || error_msg "Invalid saved vars directory" "vars" || return
	fi

	# so we have: $addons_dir for the addons folder and $saved_vars_dir for the common saved vars folder

	# === create symlinks === #

	echo ""
	symlinkCount=0

	if [ "$can_do_dir" -eq 0 ]; then
		for addon_name in "${addons_to_symlink[@]}"; do
			toPath="$addons_dir/$addon_name"
			if [ -z "$addon_name" ] || [ ! -d "$toPath" ]; then
				echo -e "Invalid addons_to_symlink element: addon not found, skipping..."
				continue
			fi

			echo -e "Creating \e[4mdirectory\e[0m symlinks for \e[4m$addon_name\e[0m..."
			internal_addon_dir "$toPath" "$addon_name" || error_msg "Could not create symbolic links for \"$addon_name\"" || return
		done
	fi

	if [ "$can_do_saved_dir" -eq 0 ]; then
		echo -e "Creating \e[4msaved variables\e[0m symlinks..."
		internal_saved_dir "$saved_vars_dir" || error_msg "Could not create symbolic links for the saved variables" || return
	fi

	echo ""
	echo "Complete. Created $symlinkCount symbolic links"
}

# ========== SCRIPT START ================================================================ #

# first of all, we change the local execution to be the script's folder,
# so that it works wherever we call it
cd "$(dirname "$0")" || exit

# check the script vars
test -n "$main_addon" || error_msg "Invalid main addon name"   "vars" || exit
test -n "$addons_dir"      || error_msg "Invalid addons directory"  "vars" || exit

# check the paths
addons_dir="$(cd "$addons_dir" && pwd)" # to absolute path
toc_file="$addons_dir/$main_addon/$main_addon.toc"
test -d "$addons_dir"      || error_msg "Invalid addons directory"  "vars" || exit
test -f "$toc_file"        || error_msg "toc file not found"        "vars" || exit

# ========== PROCESS ARGUMENTS ========== #

if [ "$1" == "--local" ]; then
	# PACKAGE COMMAND

	find_version || exit

	read -p "$(echo -e "Package $main_addon locally? (version \e[4m$version\e[0m) [y/N] ")" -n 1 -r
	echo ""
	if [[ $REPLY =~ ^[Yy]$ ]]
	then
		package "${@:2}"
	fi
elif [ "$1" == "--publish" ]; then
	# PUBLISH COMMAND

	find_version || exit

	read -p "$(echo -e "\e[1mPublish\e[0m $main_addon for version \e[4m$version\e[0m ? [y/N] ")" -n 1 -r
	echo ""
	if [[ $REPLY =~ ^[Yy]$ ]]
	then
		publish
	fi
elif [ "$1" == "--symlink" ]; then
	# MAKE LINKS COMMAND
	make_links "$2"
else
	# we misstyped something, or we typed "--help"
	usage
fi

exit
