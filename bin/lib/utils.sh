info() {
	echo "-----> $*"
}

function indent() {
  c='s/^/       /'
  case $(uname) in
    Darwin) sed -l "$c";;
    *)      sed -u "$c";;
  esac
}

get_project_file() {
	local projectfile=$(x=$(dirname $(find $1 -maxdepth 1 -type f | head -1)); while [[ "$x" =~ $1 ]] ; do find "$x" -maxdepth 1 -name *.csproj; x=`dirname "$x"`; done)
	echo $projectfile
}

get_project_name() {
	local project_name=""
	local project_file="$(get_project_file $1)"
	if [[ $project_file ]]; then
		project_name=$(basename ${project_file%.*})
	fi
	echo $project_name
	}

get_linux_platform_version() {
	if [ -e /etc/os-release ]; then
	    . /etc/os-release
	    echo ${VERSION_ID//[a-z]/}
	    return 0
	fi

	info "Linux specific platform version could not be detected: UName = $uname"
	return 1
}
get_framework_version() {
	local target_framework=$(grep -oPm1 "(?<=<TargetFramework>)[^<]+" $1/*.csproj)
	if [[ $target_framework =~ ";" ]]; then
	 	echo $(cut -d ';' -f 1 <<< $target_framework)
	else
		echo ${target_framework//[a-z]/}
	fi
}

get_runtime_framework_version() {
	local runtime_framework_version=$(grep -oPm1 "(?<=<RuntimeFrameworkVersion>)[^<]+" $1/*.csproj)
	if [[ ${#runtime_framework_version} -eq 0 ]]; then
		echo "Latest"
	else
		echo "${runtime_framework_version//[a-z]/}"
	fi
}

# Apt support

function apt_install(){
	local apt_cache_dir="$CACHE_DIR/apt/cache"
	local apt_state_dir="$CACHE_DIR/apt/state"

	mkdir -p "$apt_cache_dir/archives/partial"
	mkdir -p "$apt_state_dir/lists/partial"

	local apt_options="-o debug::nolocking=true -o dir::cache=$apt_cache_dir -o dir::state=$apt_state_dir"

	info "Cleaning apt caches"
	apt-get $apt_options clean | indent

	info "Updating apt caches"
	apt-get  --allow-unauthenticated $apt_options update | indent

	if [ ! -d "$BUILD_DIR/.apt" ]; then
		mkdir -p "$BUILD_DIR/.apt"
	fi

	declare -i is_pakage_downloaded=0
	
	for package in "$@"; do
		local has_installed_package=""
		
		if [[ $package == "openssl"* ]]; then
			has_installed_package="openssl"
		elif [[ $package == "libicu"* ]]; then
			has_installed_package="libicu"
		elif [[ $package == "xmlstar"* ]]; then
			has_installed_package="xmlstarlet"
		else
			has_installed_package=$package
		fi
		
		local has_installed=$(is_dpkg_installed $has_installed_package)
		#if [[ $has_installed == *"Unable to locate $has_installed_package"* ]]; then
			if [[ $package == *deb ]]; then
				local package_name=$(basename $package .deb)
				local package_file=$apt_cache_dir/archives/$package_name.deb
				info "Fetching $package"
				curl -s -L -z $package_file -o $package_file $package 2>&1 | indent
			else
				info "Fetching .debs for $package"
				apt-get $apt_options -y --allow-downgrades --allow-remove-essential --allow-change-held-packages -d install --reinstall $package | indent
			fi
			is_pakage_downloaded=is_pakage_downloaded+1
		#elif [[ $has_installed == *"$has_installed_package has installed"* ]]; then
		#	info "$package has installed."
		#else
		#	info "Unable to locate $has_installed_package"
		#fi
	done

	if [[ -d $apt_cache_dir/archives ]] && [[ $(find $apt_cache_dir/archives -maxdepth 1 -name '*.deb' | wc -l) -ne 0 ]]; then
		for DEB in $(ls -1 $apt_cache_dir/archives/*.deb); do
			#dpkg --info $DEB
			info "Installing $(basename $DEB)"
			dpkg -x $DEB "$BUILD_DIR/.apt/"
		done
	fi
	
	export PATH="$PATH:$BUILD_DIR/.apt/usr/bin"
	export LD_LIBRARY_PATH="$BUILD_DIR/.apt/usr/lib/x86_64-linux-gnu:$BUILD_DIR/.apt/usr/lib/i386-linux-gnu:$BUILD_DIR/.apt/usr/lib:${LD_LIBRARY_PATH-}"
	export LIBRARY_PATH="$BUILD_DIR/.apt/usr/lib/x86_64-linux-gnu:$BUILD_DIR/.apt/usr/lib/i386-linux-gnu:$BUILD_DIR/.apt/usr/lib:${LIBRARY_PATH-}"
	export INCLUDE_PATH="$BUILD_DIR/.apt/usr/include:${INCLUDE_PATH-}"
	export CPATH="${INCLUDE_PATH-}"
	export CPPPATH="${INCLUDE_PATH-}"
	echo "Environment variables has exported"
}

is_dpkg_installed() {

	if [ "$(uname)" = "Linux" ]; then
		if [ ! -x "$(command -v ldconfig)" ]; then
		    info "ldconfig is not in PATH, trying /sbin/ldconfig."
		    LDCONFIG_COMMAND="/sbin/ldconfig"
		else
		    LDCONFIG_COMMAND="ldconfig"
		fi

		local librarypath="$BUILD_DIR/.apt/usr/bin:${LD_LIBRARY_PATH-}"
		#librarypath=$(string_replace "$librarypath" "$BUILD_DIR" "$HOME")
		#echo "$LDCONFIG_COMMAND -NXv ${librarypath//:/ } 2>/dev/null  | grep $1"
		if [[ -z "$($LDCONFIG_COMMAND -NXv ${librarypath//:/ } 2>/dev/null | grep $1)" ]]; then
			echo "Unable to locate $1"
		else
			echo "$1 has installed"
		fi
	fi
	
    	return 0
}