#!/bin/bash

: '

This build script is used for 3 things:
	- Package addons locally, using the latest BigWigsMods/packager/release.sh script
	- Publish addons, using git flow, git actions and the packager script
	- Create symlinks, to setup the addon dev environment

For the Package and Publish command, the packager script will search for,
and use a ".pkgmeta" file at the source of your git repository.

The Package command will create the builds inside of the "package_dir" folder.

The Publish command will use git flow to create a tag and a release using the "main_addon" version as a name,
it will then push it to github where the release.yml file will automatically start an action to call the packager script,
and this time it will not build locally, but create and publish a release on github and on curseforge (depending on the "X-" metadatas in the TOC file).

The Symlink command will create symlinks between the WoW addons folders, and the specified addons inside the repository ("addons_to_symlink"),
see https://github.com/WeakAuras/WeakAuras2/wiki/Lua-Dev-Environment#create-symlinks to understand what I mean.
The -d option will make the symlinks target the repository ("addons_dir") addons, whereas the -b option will make the symlinks
target the build ("package_dir") addons, useful if you want to test your local builds.
You can also create symlinks for a common "SavedVariables" folder, that will be used to source all saved variables for every WoW version,
so you will share the same saved variables between Retail ("_retail_") and Classic ("_classic_"), for example.

You can modify the variables just below to customize the behavior of the script.

'

# addons info

main_addon="Nys_ToDoList"                           # The name of the main addon folder and toc file. Used to find out the addon version that will be used as a tag for the Publish command
addons_dir="."                                      # The path to the dev addon folder (usually the repository). Either absolute (/*) or relative (*)

# --local

package_dir=".other/package"                        # The name/path for the package folder (--local command). The script will create it if it doesn't exist. Prefer somewhere ignored by a gitignore. Either absolute (/*) or relative (*)

# --symlink -d|-b

addons_to_symlink=()                                # Found in $addons_dir or $package_dir
addons_to_symlink+=("$main_addon")
addons_to_symlink+=("Nys_ToDoList_Backup")

# --symlink -d|-b|-f

wow_dir="/c/Program Files (x86)/World of Warcraft"  # Only absolute (/*)

wow_versions=()                                     # Add/Remove wow versions below
wow_versions+=("_retail_")
wow_versions+=("_classic_")
wow_versions+=("_classic_era_")
wow_versions+=("_ptr_")
wow_versions+=("_ptr2_")
wow_versions+=("_beta_")

# --symlink -f

saved_vars_dir="$wow_dir/SavedVariables"           # Common saved vars folder path, the one we will point to for every WoW version. Either absolute (/*) or relative (*)
account_file_names=()                              # Add/Remove account file names below
account_file_names+=("122995789#1")
account_file_names+=("122995789#2")

# ========== FUNCTIONS ================================================================ #

# ========== UTILS ========== #

function usage()
{
	cat <<-'EOF' >&2
	Usage: build.sh [MODE]
	[MODE] can be ONE of these:

      --local [-b] [-a {args}]      Build the addon locally.
                                    The -b option will automatically launch the "--symlink -b" command once the build succeeds.
                                    If any {args} are specified, they will be sent to the packaging script.

      --publish                     Launch the process to publish the current addon version.
                                    Will prompt for validation before starting.

      --symlink (-d|-b|-s)          Create symlinks.
                                    The option is either -d (addon dev folders), -b (addon build folders) or -s (saved variables folders).

	Note:
	  If executed from the file explorer (double-click), a prompt will appear and the arguments will default to "--symlink -{INPUT}".
	EOF

	return 1
}

function from_explorer()
{
	if (( SHLVL < 2 )) ; then # if we double-clicked on the script (not running from a terminal)
		return 0
	fi

	return 1
}

function custom_exit()
{
	local last=$?

	if from_explorer ; then
		echo ""
		read -n 1 -s -r -p "Press any key to continue..."
	fi

	exit $last
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
	local last=$?

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
	local last=$?

	local msg line

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
			echo "** </> $1 ERROR </> **"
			echo "** </> Check log for more information </> **"
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

function check_package_dir()
{
	test -n "$package_dir" || error_msg "Invalid package directory" "vars" || return

	if [ ! -d "$package_dir" ]; then # if the package dir doesn't exist
		mkdir -v "$package_dir" || return # we create it
	fi

	package_dir="$(cd "$package_dir" && pwd)" # to absolute path

	test -n "$package_dir" -a -d "$package_dir" || error_msg "Invalid package directory" "vars" || return
}

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

		local steps="5"
		if [ "$1" == "-b" ]; then
			steps="6"
		fi

		step_msg 1 "$steps" "Check for the package directory"
		check_package_dir || return
		echo "Package directory: \"$package_dir\""

		# then we clear the old builds in the package folder
		step_msg 2 "$steps" "Cleanup the package directory"
		rm -rfv "${package_dir:?}/${main_addon:?}"* || return
		test ! -e "$package_dir/release.txt" || rm -fv "$package_dir/release.txt" || error_msg "Invalid file found at \"$package_dir/release.txt\", please remove it and try again" || return

		# and we curl the packaging script from 'BigWigsMods/packager' on GitHub
		# NOTE: using a txt file so that we don't risk executing it in the file explorer by mistake, and we have a trace of the last script used
		step_msg 3 "$steps" "Curl the packaging script (from GitHub)"
		curl -sv "https://raw.githubusercontent.com/BigWigsMods/packager/master/release.sh" > "$package_dir/release.txt" || return
		echo -e "\nDownloaded the packaging script to \"$package_dir/release.txt\""

		# here we get potential additional arguments to send to release.txt
		step_msg 4 "$steps" "Process the additional arguments"
		local args="" mark="0"
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

		# we call release.txt with the good arguments
		step_msg 5 "$steps" "Run the packaging script"
		(cd "$package_dir" || exit; ./release.txt -r "$(pwd)" -d $args) || return

		if [ "$1" == "-b" ]; then
			step_msg 6 "$steps" "Create build symlinks"
			make_links "-b" || return
		fi
	}

	build_msg "BUILD" 1

	internal "$@" || build_msg "BUILD" 3 || return

	echo ""
	echo "Addon(s) packaged to \"$package_dir\"."
	echo "Version $version of $main_addon has been packaged."
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

	# make sure we are on the dev branch
	echo ""
	test "$dev_branch_name" == "$(git branch --show-current)" || error_msg "The develop branch needs to be checked out" || return

	# check the TAG_EDITMSG file
	test ! -e "TAG_EDITMSG" -o -f "TAG_EDITMSG" || error_msg "Invalid file found at \"$(pwd)/TAG_EDITMSG\", please remove it and try again" || return
}

function publish()
{
	function internal()
	{
		# will cancel the execution if something isn't available
		check_publish_execution || return

		step_msg 1 5 "Start release"
		git flow release start "$version" || return

		echo -e "Create tag message \"v$version\" > 'TAG_EDITMSG'"
		echo "v$version" > "TAG_EDITMSG" || return

		step_msg 2 5 "Finish release"
		git flow release finish "$version" -f "TAG_EDITMSG" || return

		rm -fv "TAG_EDITMSG" || return

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

		local version to_path to
		for version in "${wow_versions[@]}"; do
			to_path="$wow_dir/$version/Interface/AddOns" # WOW ADDON PATH
			if [ ! -d "$to_path" ]; then
				echo -e "\e[33m-\e[0m WoW \"$version\" version not found"
				continue
			fi

			to="${to_path:?}/${2:?}"
			test ! -f "$to" -a ! -d "$to" -a ! -L "$to" || rm -rf "$to"

			ln -s "$1" "$to" || return
			echo -e "\e[32m+\e[0m \"$to\" (symlink) --> (target) \"$1\""
			symlink_count=$((symlink_count+1))
		done
	}

	function internal_saved_dir()
	{
		test -d "$1" || error_msg "Invalid source folder for saved variables links" "vars" || return

		local version to_path account to_path_account to
		for version in "${wow_versions[@]}"; do
			to_path="$wow_dir/$version/WTF/Account" # WOW SAVED VARIABLES PATH
			if [ ! -d "$to_path" ]; then
				echo -e "\e[33m-\e[0m WoW \"$version\" version not found"
				continue
			fi

			for account in "${account_file_names[@]}"; do
				to_path_account="$to_path/$account" # WOW SAVED VARIABLES PATH
				if [ ! -d "$to_path_account" ] || [ -z "$account" ]; then
					echo -e "\e[33m-\e[0m Account \"$account\" not found for \"$version\""
					continue
				fi

				to="${to_path_account:?}/SavedVariables"
				if [ -d "$to" ]; then
					if [ ! -L "$to" ] && [ -n "$(ls -A "$to")" ]; then
						echo -e "\e[31m-\e[0m Found a non-empty SavedVariables directory, skipping. Please backup, remove the folder and try again (\"$to\")"
						continue
					fi
					rm -rf "$to"
				fi

				ln -s "$1" "$to" || return
				echo -e "\e[32m+\e[0m \"$to\" (symlink) --> (target) \"$1\""
				symlink_count=$((symlink_count+1))
			done
		done
	}

	# === check all variables and paths === #

	test "$1" == "-d"
	local can_do_dev_dir=$?

	test "$1" == "-b"
	local can_do_build_dir=$?

	test "$1" == "-s"
	local can_do_saved_dir=$?

	if [ "$can_do_dev_dir" -ne 0 ] && [ "$can_do_build_dir" -ne 0 ] && [ "$can_do_saved_dir" -ne 0 ]; then
		usage
		return
	fi

	if [ "$can_do_dev_dir" -eq 0 ] && [ "$can_do_build_dir" -eq 0 ]; then
		usage
		return
	fi

	ln --version || error_msg "The \"ln\" command must be installed to create symbolic links" || return
	export MSYS=winsymlinks:nativestrict || return # to create real symlinks with ln, not just copies

	test -n "$wow_dir" -a -d "$wow_dir" || error_msg "Invalid WoW directory" "vars" || return
	test "${#wow_versions[@]}" -ne 0 || error_msg "No WoW version has been specified" "vars" || return

	if [ "$can_do_dev_dir" -eq 0 ]; then
		: # $addons_dir has already been verified
	fi

	if [ "$can_do_build_dir" -eq 0 ]; then
		check_package_dir || return
	fi

	if [ "$can_do_saved_dir" -eq 0 ]; then
		test "${#account_file_names[@]}" -ne 0 || error_msg "No account file name has been specified" "vars" || return

		test -n "$saved_vars_dir" || error_msg "Invalid saved vars directory" "vars" || return
		saved_vars_dir="$(cd "$saved_vars_dir" && pwd)" # to absolute path
		test -n "$saved_vars_dir" -a -d "$saved_vars_dir" || error_msg "Invalid saved vars directory" "vars" || return
	fi

	# so we have: $package_dir for the addons build folder, $addons_dir for the addons dev folder and $saved_vars_dir for the common saved vars folder

	# === create symlinks === #

	echo ""
	local symlink_count=0 to_path addon_name

	if [ "$can_do_dev_dir" -eq 0 ]; then
		for addon_name in "${addons_to_symlink[@]}"; do
			to_path="$addons_dir/$addon_name"
			if [ -z "$addon_name" ] || [ ! -d "$to_path" ]; then
				echo -e "Addon \"$addon_name\" not found at \"$addons_dir\", skipping..."
				continue
			fi

			echo -e "Creating \e[4mdev directory\e[0m symlinks for \e[4m$addon_name\e[0m..."
			internal_addon_dir "$to_path" "$addon_name" || error_msg "Could not create dev symbolic links for \"$addon_name\"" || return
		done
	fi

	if [ "$can_do_build_dir" -eq 0 ]; then
		for addon_name in "${addons_to_symlink[@]}"; do
			to_path="$package_dir/$addon_name"
			if [ -z "$addon_name" ] || [ ! -d "$to_path" ]; then
				echo -e "Addon \"$addon_name\" not found at \"$package_dir\", skipping..."
				continue
			fi

			echo -e "Creating \e[4mbuild directory\e[0m symlinks for \e[4m$addon_name\e[0m..."
			internal_addon_dir "$to_path" "$addon_name" || error_msg "Could not create build symbolic links for \"$addon_name\"" || return
		done
	fi

	if [ "$can_do_saved_dir" -eq 0 ]; then
		echo -e "Creating \e[4msaved variables\e[0m symlinks..."
		internal_saved_dir "$saved_vars_dir" || error_msg "Could not create symbolic links for the saved variables" || return
	fi

	echo ""
	echo "Complete. Created $symlink_count symbolic links"
}

# ========== SCRIPT START ================================================================ #

# first of all, we change the local execution to be the script's folder,
# so that it works wherever we call it
cd "$(dirname "$0")"   || custom_exit

# check the script vars
test -n "$main_addon"  || error_msg "Invalid main addon name"   "vars" || custom_exit
test -n "$addons_dir"  || error_msg "Invalid addons directory"  "vars" || custom_exit

# check the paths
addons_dir="$(cd "$addons_dir" && pwd)" # to absolute path
toc_file="$addons_dir/$main_addon/$main_addon.toc"
test -d "$addons_dir"  || error_msg "Invalid addons directory"  "vars" || custom_exit
test -f "$toc_file"    || error_msg "toc file not found"        "vars" || custom_exit

# ========== PROCESS ARGUMENTS ========== #

if from_explorer ; then
	read -p "$(echo -e "Select symlink mode [d/b] ")" -n 1 -r
	echo ""
	if [[ $REPLY =~ ^[Dd]$ ]]; then
		set -- "--symlink" "-d"
	elif [[ $REPLY =~ ^[Bb]$ ]]; then
		set -- "--symlink" "-b"
	fi
fi

if [ "$1" == "--local" ]; then
	# PACKAGE COMMAND

	find_version || custom_exit

	read -p "$(echo -e "\e[1mPackage locally\e[0m $main_addon for version \e[4m$version\e[0m ? [y/N] ")" -n 1 -r
	echo ""
	if [[ $REPLY =~ ^[Yy]$ ]]
	then
		package "${@:2}"
	fi
elif [ "$1" == "--publish" ]; then
	# PUBLISH COMMAND

	find_version || custom_exit

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

custom_exit
