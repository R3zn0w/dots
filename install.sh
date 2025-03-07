#!/bin/bash

# GLOBALS
g_BACKUPPATH="$HOME/.config_backed_up"

# USER-PROVIDED
u_NOINSTALL=false
u_NOBACKUP=false
u_DEBUG=true #add switch

function print_help(){ # dynamically lookup supported collections
	echo -e "\n---Dots setup---"
	echo -e "Sets up the dotfiles, supply the args or suffer the interactive hellhole"
	echo -e "Arguments:"
	echo -e "-h/--help - this help"
	echo -e "-c/--collection <coll_name> - (required) what to set up"
    for coll in "${!mapped_packages[@]}";do
            echo -e "\t$coll - ${mapped_packages[$coll]}"
    done
	echo -e "-ni/--no-install - by default this tool tries to install the programs for which config is copied. This option disables that"
	echo -e "-nb/--no-backup - by default this tool backups any previously present config to ~/.config_backed_up/ folder. This option disables that"
}

function debug(){
        if [ $u_DEBUG = true ]; then
                echo -e "$1"
        fi
}

function field_exists(){
# $1 is searched field, $2 is array of fields
        local search_field="$1"
        shift
        local array=("$@")
        for item in "${array[@]}"; do
                if [[ "$item" == "$search_field" ]]; then
                        return 0
                fi
        done
        return 1  
}

function dirmk(){
        if [ ! -d $1 ]; then
                echo "Folder $1 does not exist, creating"
                mkdir -p $1
        fi
}

#set -e
#set -u
trap 'echo "Something went horribly wrong on line $LINENO"; exit 1' ERR


# parse packages in config
available_colls=($(jq -r '.collections|keys[]' config.json))
declare -A mapped_packages
for coll in "${available_colls[@]}"; do
        while read -r package; do
                mapped_packages[$coll]="${mapped_packages[$coll]} $package"
        done < <(jq -r ".collections.${coll}[]" config.json)
done

# parse opts
while [[ "$#" -gt 0 ]]; do
	case $1 in
	-h|--help) print_help
		exit 0
		;;
	--collection=*) u_COLL="${1#*=}"
		shift
		;;
	-c|--collection) u_COLL="$2"
		shift
		shift
		;;
	-ni|--no-install) u_NOINSTALL=true
		shift
		;;
	-nb|--no-backup) u_NOBACKUP=true
		shift
		;;
	*) echo "Unknown parameter passed: $1"
		print_help
		exit 1
		;;
	esac
done

# check if selected collection is supported (present in config)
if [[ ! " ${!mapped_packages[@]} " =~ [[:space:]]${u_COLL}[[:space:]] ]]; then
    echo -e "No such collection!"
    print_help
    exit 1
fi

# prepare backup space
if [ "$u_NOBACKUP" = true ]; then
        echo -e "Running without backup, waiting 2s for your interrupt"
        sleep 2
else
        if [ -d "$g_BACKUPPATH" ]; then
                echo -e "Dropping old backup folder at $g_BACKUPPATH"
                rm -rf "$g_BACKUPPATH"
        fi
        dirmk "$g_BACKUPPATH"
fi

declare -a faulty_packages
for desired_package in ${mapped_packages[$u_COLL]}; do
        declare -A pkg_info=()
        declare -a pkg_fields=()
        declare tmp_res
        
        # check whether the package is actually defined
        debug "Parsing pkg $desired_package"
        tmp_res=$(jq -r ".packages|has(\"$desired_package\")" config.json)
        if [ $tmp_res == "false" ]; then
                echo "Missing package $desired_package definition in config.json"
                faulty_packages+=($desired_package)
                continue
        fi

        # check whether the package definition contains any fields
        debug "Parsing fields of $desired_package"
        tmp_res=$(jq -r ".packages.$desired_package // empty" config.json)
        if [[ -z $tmp_res ]]; then
                echo "Missing fields in package $desired_package definition in config.json"
                faulty_packages+=($desired_package)
                continue
        fi

        # parse the package and get the field keys
        debug "Getting field values of $desired_package"
        while read -r field; do
                pkg_fields+=($field)
        done < <(jq -r ".packages.${desired_package}|keys[]" config.json)

        # get field values
        for field in "${pkg_fields[@]}"; do
                while read -r val; do
                pkg_info[$field]="$val"
                done< <(jq -r ".packages.${desired_package}.${field}" config.json)
        done
        
        declare -p pkg_info

        # backup old config
        if field_exists "confSrcPath" "${pkg_fields[@]}"  && field_exists "confTgtPath" "${pkg_fields[@]}" ;then
                pkg_info[confTgtPath]=$(eval echo "${pkg_info[confTgtPath]}") #terrible hack to evaluate variables in config
                if [ "$u_NOBACKUP" = false ]; then
                        if [ -d "${pkg_info[confTgtPath]}" ]; then
                                echo -e "Backing up old config at ${g_BACKUPPATH}${pkg_info[confTgtPath]}"
                                dirmk "${g_BACKUPPATH}${pkg_info[confTgtPath]}"
                                cp -Lr "${pkg_info[confTgtPath]}" "${g_BACKUPPATH}${pkg_info[confTgtPath]}"
                        fi
                fi
		# try creating the whole directory tree and remove the top one. Ensures that both root directory exists and old config is purged at the same time
		dirmk "${pkg_info[confTgtPath]}"
        	rm -rf "${pkg_info[confTgtPath]}"
        else
                echo "$desired_package lacks confSrcPath and confTgtPath"
                faulty_packages+=($desired_package)
                continue
        fi
       
	# install package (if needed)
	# TODO actually implement that
        if [ "$u_NOINSTALL" = false ] && field_exists "pkgMgrName" "${pkg_fields[@]}";then
                debug "Running installation of $desired_package"
        fi

	# remove colliding configs created by installers and link our config
	if [ -d "${pkg_info[confTgtPath]}" ]; then
		debug "Removing installer's default config for ${desired_package}"
		rm -rf "${pkg_info[confTgtPath]}"
	fi
	
	debug "Linking config for ${desired_package}"
	ln -s "$PWD/${pkg_info[confSrcPath]}" "${pkg_info[confTgtPath]}"
	
	echo "Package ${desired_package} done!"
done

# install package

# link the config directories

echo -e "The following packages failed the installation: "
for package in ${faulty_packages[@]}; do
        echo -e "\t-$package"
done
