#! /bin/bash

echo "TEST START"
echo "----------"

pkg="notebook"
initial="$(pip list)"

printf "%s\n" "START INSTALL $pkg"
pip install "$pkg"
printf "%s\n\n" "INSTALLED $pkg"
pip list

printf "\n%s\n\n" "START UNINSTALL $pkg"
../pip-uninstall.sh "$pkg"
echo "UNINSTALLED $pkg"
final="$(pip list)"

echo "RESULT:"
if [[ "$initial" == "$final" ]]
then
    printf "\033[32m%s\033[0m\n" "PASSED"
    exit 0
else
    printf "\033[31m%s\033[0m\n" "FAILED"
    exit 1
fi

echo "--------"
echo "TEST END"