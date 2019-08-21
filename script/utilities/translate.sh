#!/bin/bash

currentDirectory=$(basename "$PWD")

if [ "$currentDirectory" != "libki-server" ]; then
	echo "This can only be run from your libki-server directory."
	exit 1
fi

if [ $# -eq 0 ]; then
	echo "No arguments supplied."
	echo
	echo "Use --generate or -g to update messages.pot."
	echo
	echo "Use --update or -u to update all po files to the current messages.pot."
fi

# Flags
while [ ! $# -eq 0 ]
do
	case "$1" in
		--help | -h)
			echo "Use --generate or -g to update messages.pot."
			echo
			echo "Use --update or -u followed by your po file to update it to the current messages.pot."
			echo "Example: ./libki-i18n.sh -u lib/Libki/I18N/sv.po"
			exit 0
			;;
		--generate | -g)
			# Install xgettext.pl if needed
			sudo cpanm Locale::Maketext::Extract

			rm lib/Libki/I18N/messages.pot
			xgettext.pl --output=lib/Libki/I18N/messages.pot --directory=root/
			cat lib/Libki/I18N/extras.pot >> lib/Libki/I18N/messages.pot

			echo "Generation complete. Enjoy your fresh messages.pot file!"

			exit 0
			;;
		--update | -u)
			gettextInstalled=$(which gettext)

			if [ -z "$gettextInstalled" ]; then
				sudo apt install gettext
			fi

			timestamp=$(date +"%y%m%d_%H:%M")

			sed -i '/^#:/ d' $2

			msgmerge -U $2 lib/Libki/I18N/messages.pot --suffix=_backup_$timestamp

			echo "Update complete. Your translation file is updated to the current messages.pot."
			echo
			echo "A backup of your old file was created, too. Please delete that once your translation is done."
			exit 0
			;;
		*)
			echo "Welcome to the Libki Translation Updater."
			echo
			echo "Use --help for instructions."
      			exit 1
			;;

	esac
	shift
done
