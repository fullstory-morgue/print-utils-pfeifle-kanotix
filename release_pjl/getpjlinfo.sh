#!/bin/bash
#
# Frage PJL-Optionen von lokalen oder Netzwerdruckern ab
#
# Till Kamppeter <till.kamppeter@gmx.net>
# Kurt Pfeifle <kpfeifle@danka.de>
# Copyright 2004 Till Kamppeter, Kurt Pfeifle
#
# Cleanup and english translation by Fabian Franz
# Ist das hier GPL?
#
# set -x
#

PROGNAME=$(basename $0)

# Wenn kein Script aufgerufen wurde, dann nimm die Kommandos von stdin ...
export pjl_commands="cat -"
export HELP_TEXT=

# Welches Script wurde aufgerufen?
case $PROGNAME in
	holepjloptionen.sh)
		LANG="de";
		pjl_commands=pjl_commands_get_info
		HELP_TEXT="   Die vom Drucker preisgegebene Optionsliste wird an 'Standard-Out' geschickt."
	;;	
	getpjloptions.sh)
		LANG="us";
		pjl_commands=pjl_commands_get_info
		HELP_TEXT="   The received option list is send to 'standard-out'."
	;;
	holeseitenzaehler.sh)
		LANG="de";
		pjl_commands=pjl_commands_get_pagecounter
		HELP_TEXT="   Der vom Drucker preisgegebene Zaehlerstand wird an 'Standard-Out' geschickt."
	;;
	getpagecounter.sh)
		LANG="us";
		pjl_commands=pjl_commands_get_pagecounter
		HELP_TEXT="   The received page counter is send to 'standard-out'."
	;;

esac

if [ "$3" = "" ]; then  
	SLEEPTIME=1
else
	SLEEPTIME=$[$3+1]
fi

# functions
pjl_commands_get_info()
{
	# PJL-Kommandos zu Abfrage der Drucker-Informationen:
	echo -en "\033%-12345X"
	echo -en "@PJL\r\n"
	echo -en "@PJL INFO VARIABLES\r\n"
	echo -en "@PJL INFO ID\r\n"
	echo -en "@PJL INFO CONFIG\r\n"
}

pjl_commands_get_pagecounter()
{
	echo -en "\033%-12345X"
	echo -en "@PJL\r\n"
	echo -en "@PJL INFO PAGECOUNT\r\n"
}

pjl_net()
{
	# Wir haben zwei Argumente --> also Abfrage ueber das Netz:
	# schicke Kommandos an den Netzdrucker:
	netcat -q 0 $1 $2 2>/dev/null
	# Mindestens eine Sekunde warten, damit der Drucker Zeit hat, die Anfrage zu 
	# bearbeiten:
	sleep $SLEEPTIME
	# Antwort des Druckers aufzeichnen und die "newpage characters" ausfiltern:
	netcat -w 1 $1 $2 2>/dev/null | perl -p -e "s/\014//"
}

pjl_local()
{
	# Wir haben ein Argument --> also Abfrage ueber die lokale Schnittstelle:
	# schicke Kommandos an den Printer-Port:
	cat > $1
	# Mindestens eine Sekunde warten, damit der Drucker Zeit hat, die Anfrage zu 
	# bearbeiten:
        sleep $SLEEPTIME
	# Antwort des Druckers aufzeichnen und "newpage characters" ausfiltern:
	cat < $1 | perl -p -e "s/\014//"
}

pjl_help()
{
case $LANG in 
	de*|at*|ch*)
		# Kein Argument --> wir zeigen den "Wie benutze ich das Ding?-Absatz":
		echo ""
		echo "Benutzung: $(basename $0) <Device>"
		echo "           $(basename $0) <Hostbezeichnung> <Port>"
		echo "           $(basename $0) <Hostbezeichnung> <Port> <Zusatz-Wartezeit>"
		echo ""
		echo "   <Device>:           Device, an welches der lokale Printer angeschlossen ist."
		echo "                       Beispiele: /dev/lp0, /dev/usb/lp0"
		echo "                       Der Parallel-Port sollte sich in 'EPP/bi-direktionalem"
		echo "                       Modus' befinden (siehe BIOS-Einstellungen)."
		echo "   <Hostbezeichnung>:  Hostname oder IP-Addresse eines Netzwerkdruckers mit HP"
		echo "                       JetDirect- oder Socket-Verbindung ...)"
		echo "   <Port>:             Portnummer des Netzwerkdruckers (meist 9100)."
		echo
		echo "   <Zusatz-Wartezeit>: Ganze Zahl (z.B. 1, 2, oder 3) für Einhaltung einer"
		echo "                       Zeitspanne in Sekunden für das Warten auf die Antwort"
		echo "                       des Druckers."
		echo
		echo "   Uni-direktionale Protokolle wie 'remote LPD' werden nicht unterstuetzt."
		echo ""
		#echo "   Die vom Drucker preisgegebene Optionsliste wird an 'Standard-Out' geschickt."
		echo ${HELP_TEXT:-"Es können beliebige Befehle über stdin geschickt werden. Die Ausgabe erfolgt auf stdout"}
		
		echo ""
	;;
	*)
		echo ""
		echo "Usage: $(basename $0) <Device>"
		echo "       $(basename $0) <Hostname> <Port>"
		echo "       $(basename $0) <Hostname> <Port> <Additional Delay>"
		echo ""
		echo "   <Device>:           Device to which the local printer is attached."
		echo "                       Examples: /dev/lp0, /dev/usb/lp0"
		echo "                       The parallel port should be in 'EPP/bi-directional"
		echo "                       mode (look at your bios settings)."
		echo "   <Hostname>:         Hostname or IP-Address of a network printer with HP"
		echo "                       JetDirect- oder Socket-Connection ...)"
		echo "   <Port>:             Portnumber of the network printer. (in most cases 9100)"
		echo
		echo "   <Additional Delay>: Integer (i.e 1, 2, oder 3) to complicance with"
		echo "                       a delay in seconds for waiting for an answer"
		echo "                       of the printer."
		echo
		echo "   uni-directional protocols like 'remote lpd' are not supported."
		echo ""
		#echo "   The received option list is send to 'standard-out'."
		echo ${HELP_TEXT:-"You can send commands via stdin. The received answer is sent to stdout"}
		echo ""

	;;
esac
}

case $# in
	1)
		$pjl_commands | pjl_local $1
	;;
	2|3)
		$pjl_commands | pjl_net $1 $2
	;;
	*)
		pjl_help
esac
