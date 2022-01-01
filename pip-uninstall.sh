#! /bin/bash
# Uninstalls python package installed with pip
# and it's unused dependencies
# 
# PROBLEMS:
# - Will fail on circular dependencies
# - Will fail on version clash
# - Some packages may not be uninstalled as whitelisted packages are added
#   as packages are being removed, not before

verbose=false  # Default not verbose
to_remove=()  # Initialise packages to remove to empty arr
blacklisted=("pip" "setuptools" "wheel")  # Packages not to remove

# Helper function to print message in yellow
# Prints to stdout not stderr as it is only a warning, not err
warn() {
    printf "\033[33m%s\033[0m\n" "$1"
}

# Check if pip is installed / added to path
# Could invoke pip through `python -m pip` but i'm too lazy for that
if ! command -v pip &>/dev/null
then
    warn "pip is either not installed or not added to PATH"
    exit 1
fi

print_help() {
    printf "USAGE:
    pip-uninstall [OPTIONS] [PACKAGE]
    
    OPTIONS:            DESCRIPTION:
        -h | --help     Display help message
        -v | --verbose  Be verbose
"
}

# Confirm removal of package
# Arguments:
#   $1 : string
#       The package to be removed
#
# Returns:
#   0 - Chose NO ("n")
#   1 - Chose YES ("Y")
#   2 - Chose invalid option (not "Y" or "n")
confirm() {
    printf "Remove package '$1'? [Y/n] "
    read choice
    choice="${choice//' '/}"  # Strip whitspace
    choice="$(echo $choice | tr '/a-z/' '/A-Z/')"  # Case insensitive (convert to upper)

    if [[ "$choice" == "N" ]]  # Chose no - do not uninstall pkg
    then
        echo "Aborting uninstall of '$1'"
        return 0
    elif [[ "$choice" == "Y" ]]  # Chose yes - uninstall pkg
    then
        echo "Starting uninstall of '$1'"
        return 1
    fi

    return 2  # Invalid option chosen
}

# Arguments:
#   $1 : string 
#       The package to be removed
#   $2 : array
#       The array of whitelisted parent packages
remove_package() {
    # Package to remove is blacklisted (pip, wheel, setuptools) - do not remove
    if [[ " ${blacklisted[@]} " =~ " $1 " ]]
    then
        warn "  Package '$1' is blacklisted"
        warn "  Aborting uninstall of '$1'"
        return 1
    fi

    whilelisted=($2)
    echo "Removing package '$1'"

    # Get dependencies of package as array
    deps_str="$(pip show $1 | grep Requires:)"
    IFS=", " read -r -a deps <<< ${deps_str//Requires: /}

    # Get parent packages (what packages it is required by) as array
    req_by_str="$(pip show $1 | grep Required-by:)"
    IFS=", " read -r -a req_by <<< ${req_by_str//Required-by: /}

    if [[ $verbose == true ]]  # Extra info if -v | --verbose option chosen
    then
        echo "  reqs:        ${deps[@]}"
        echo "  required by: ${req_by[@]}"
        echo "  whitelisted: ${whitelisted[@]}"
    fi

    # Make sure package (or dependency) is not required
    # by any other packages (that are not whitelisted)
    for parent_pkg in ${req_by[@]}
    do
        # Package required by another package (not whitelisted) - abort uninstall
        if ! [[ "${whitelisted[@]}" =~ "$parent_pkg" ]]
        then
            warn "  Package '$1' is being used by $parent_pkg"
            warn "  Aborting uninstall of '$1'"
            return 1
        fi
    done

    pip uninstall -y "$1"  # Uninstall package without confirmation (Y/n)
    
    # May contain duplicates but it doesn't affect anything (except some speed)
    whitelisted=(${whitelisted[@]} ${deps[@]})

    # Recursively remove all dependencies
    for dep in ${deps[@]}
    do
        remove_package "$dep" "${whitelisted[@]}"
    done

    return 0
}

# Option handling
while [[ $# -gt 0 ]]
do
    case "$1" in
        -h | --help)
            print_help
            exit 0
            ;;
        -v | --verbose)
            verbose=true
            ;;
        --* | -*)
            echo "'$1' is not a valid option"
            print_help
            exit 0
            ;;
        *)  # Add package name to `to_remove` array
            to_remove=("${to_remove[@]}" "$1")
        ;;
    esac
    shift
done

for pkg in "${to_remove[@]}"
do
    # Ensure package exists
    if ! pip show $pkg &>/dev/null
    then
        echo "Package '$pkg' not found"
        exit 1
    fi

    # Confirm uninstall [Y/n]
    confirm "$pkg"
    choice=$?
    while [[ $choice -eq 2 ]]
    do
        confirm "$pkg"
        choice=$?
    done

    # Chose "n" (do not uninstall)
    if [[ $choice == 0 ]]
    then
        exit 1
    fi

    # Get case sensitive package name (for regex search in `remove_package()`)
    pkg_name="$(pip show $pkg | grep Name:)"
    pkg_name="${pkg_name//Name: /}"

    echo $pkg_name

    whitelisted=("$pkg_name")  # Add package name to whitelisted
    remove_package "$pkg_name" "${whitelisted[@]}"
done

exit 0