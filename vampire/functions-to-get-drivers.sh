#!/bin/bash
#
# (C) Kurt Pfeifle <kpfeifle@danka.de>, 2004
# License: GPL
#
# Version: 0.7 (not yet fully documented -- if it ever will be....)
#
# Thanks a lot to Fabian Franz for helping me with some Bash-Scripting-Questions!
#
# This set of functions provides a framework to snatch all printer
# driver info and related files from a Windows NT print server.
# The main commands used are "smbclient" and "rpcclient" combined
# with "grep", "sed" and "awk". Probably a Perl or Python script
# would be better suited to do this, mainly because we have to cope
# with printer and driver names which are containing spaces in
# them, so a lot of shell escaping is required to handle these.
# Also, I am not very savvy in scripting, so I invented some very
# obscure methods to work around my knowledge gaps. When I download
# the driver files from the Windows NT box, I put all related driver
# files into their own sub directory, using the same name as the
# driver. Also, driver versions "0", "2" and "3" are placed in
# further subdirectories.
#
# Known problem:  I found one printer driver containing a "slash"
# --------------  which is not handled by this script: "HP Color 
# LaserJet 5/5M PS". (There are more of these in the wild, of course.)
# The reason: I didn't find a way to create a Unix directory containing 
# a "slash". The script replaces the "/" with a "_" and also renames the
# drivername accordingly, when it is uploaded to the Samba [print$]
# share....
#   This script is probably not portable at all and relies on lots
# of Bash-isms.
#
#
# Shameless plug ahead:
# ---------------------
# We provide professional help with all problems regarding
# network printing, on all OS platforms. We are specialized
# in CUPS and Samba printing on Linux and Unix systems.
# Just write a short e-Mail to ask for a quotation about our 
# daily or hourly rates.
#

#set -x

# The following functions use a few external variables to log
# into the 2 hosts. We suggest that you create a file which 
# contains the variables and that you source that file at the
# beginning of this script... 
# 
# ##########################################################
#printeradmin=Administrator  # any account on the NT host with "printer admin" privileges
#adminpasswd=not4you         # the "printer admin" password on the NT print server
#nthost=windowsntprintserverbox # the netbios name of the NT print server
#	
#smbprinteradmin=knoppix     # an account on the Samba server with "printer admin" privileges
#smbadminpasswd=2secret4you  # the "printer admin" password on the Samba server
#smbhost=knoppix             # the netbios name of the Samba print server
#
# ##########################################################
#

# NOTE: this script also works for 2 NT print servers: snatch all drivers
# from the first, and upload them to the second server (which takes the
# role of the "Samba" server). Of course it also works for 2 Samba servers:
# snatch all drivers from the first (which takes the role of the NT print
# server) and upload them to the second....

# -----------------------------------------------------------------------------
# ----------- print a little help... ------------------------------------------
function helpwithvampiredrivers()
{
	echo "  ";
	echo "  1. Run the functions of this script one by one.";
	echo "  ";
	echo "  2. List all functions with the \"enumallfunctions\" call.";
	echo "  ";
	echo "  3. After each functions' run, check if it completed successfully.";
	echo "  ";
	echo "  4. Often network conditions prevent the MS-RPC calls"
	echo "     implemented by Samba to succeed at the first attempt."
	echo "     You may have more joy if you try more than once or twice....";
	echo "  ";
	echo "  ";
	echo "  ";
	echo "  ";
	echo "  ";
}

# -----------------------------------------------------------------------------
# ----------- enumerate all builtin functions... ------------------------------
function enumallfunctions()
{
	echo " "
	echo " "
	echo "--> Running now function enumallfunctions()..."
	echo "=============================================="
	echo -e " \n\
	function enumallfunctions() 
	function helpwithvampiredrivers()
	function fetchenumdrivers3listfromNThost()      # repeat, if no success at first
	function createdrivernamelist() 
	function createprinterlistwithUNCnames()        # repeat, if no success at first
	function createmapofprinterstodriver() 
	function splitenumdrivers3list()
	function makesubdirsforW32X86driverlist()
	  function splitW32X86fileintoindividualdriverfiles()
	  function fetchtheW32X86driverfiles()
	  function uploadallW32X86drivers()
	function makesubdirsforWIN40driverlist()
	  function splitWIN40fileintoindividualdriverfiles()
	  function fetchtheWIN40driverfiles()
	  function uploadallWIN40drivers()"
	echo " "
}

# this is a helperfunction (Thanks to Fabian Franz!)
function stringinstring()
{
	case "$2" in *$1*) 
		return 0 
		;;
	esac 
		return 1
}

# -----------------------------------------------------------------------------
# ----------- Create an "enumprinters 3" list --------------------- -----------
#
# PRECONDITIONS: 1) This function expects write access to the current directory. 
#		 2) This functions expects to have the $nthosts, $printeradmin
#		    and $adminpassword variables set to according values.
# WHAT IT DOES: This function connects to the "$nthost" (using the credentials
#		$printeradmin with $adminpasswd, retrieves a list of printer
#		drivers (with related file names) from that host, and saves the
#		list under the name of "${nthost}/enumdrivers3list.txt" (ie. it
#		also creates the "$nthost" subdirectory in the current one). It
#		further prints some more info to stdout.
# IF IT DOESN'T WORK: It may happen that the function doesn't work at the first
#		      time (there may be a connection problem). Just repeat a
#		      few times. It may work then. You will recognize if it does.
#               
#
function fetchenumdrivers3listfromNThost()
{
if stringinstring help $@ ; then
helpwithvampiredrivers ;
else
	echo " "
	echo " "
	echo "--> Running now function fetchenumdrivers3listfromNThost"
	echo "========================================================"
	[ -d ${nthost} ] || mkdir "${nthost}";
	rpcclient -U${printeradmin}%${adminpasswd} -c 'enumdrivers 3' ${nthost} \
	| tee \
	${nthost}/enumdrivers3list.txt;
	NUMBEROFDIFFERENTDRIVERNAMES=$( grep "Driver Name:" ${nthost}/enumdrivers3list.txt | sort | uniq | wc -l );
	echo " ";
	echo "--> Finished in running function fetchenumdrivers3listfromNThost....";
	echo "===================================================================="
	echo "NUMBEROFDIFFERENTDRIVERNAMES retrieved from \"${nthost}\" is $NUMBEROFDIFFERENTDRIVERNAMES".;
	echo "  -->  If you got \"0\" you may want to try again. <---";
	echo "================================================================";
	echo " ";
	enumdrivers3list=`cat ${nthost}/enumdrivers3list.txt`;
fi
}


# -----------------------------------------------------------------------------
# ----------- Create a list of all available drivers installed ----------------
# ------------------------on the NT print server-------------------------------
#
# PRECONDITIONS: 1) This function expects to find the subdirectory "$nthost" 
#		    and the file "${nthost}/enumdrivers3list.txt" to exist.
#		 2) This functions expects to have the $nthosts variable set 
#		    to an according value.
# WHAT IT DOES: This function dissects the "${nthost}/enumdrivers3list.txt" 
#		and creates other textfiles from its contents:
#		- "${nthost}/drvrlst.txt"
#		- "${nthost}/completedriverlist.txt"
#		and further prints some more info to stdout.
#
function createdrivernamelist()
{
	echo " ";
	echo " ";
	echo "--> Running now function createdrivernamelist....";
	echo "=================================================";
	cat ${nthost}/enumdrivers3list.txt \
	| grep "Driver Name:" \
	| awk -F "[" '{ print $2 }' \
	| awk -F "]" '{ print $1 }' \
	| sort \
	| uniq \
	| sed -e 's/$/\"/' -e 's/^ */\"/' \
	| tee \
	${nthost}/drvrlst.txt;
	drvrlst=$(echo ${nthost}/drvrlst.txt);
	
	cat ${nthost}/enumdrivers3list.txt \
	| grep "Driver Name:" \
	| awk -F "[" '{ print $2 }' \
	| awk -F "]" '{ print $1 }' \
	| sort \
	| uniq \
	| sed -e 's/$/\"/' \
	| cat -n \
	| sed -e 's/^ */DRIVERNAME/' -e 's/\t/\="/' \
	| tee \
	${nthost}/completedriverlist.txt;
	
	NUMBEROFDRIVERS=`cat ${nthost}/completedriverlist.txt| wc -l`;
	echo " ";
	echo "--> Finished in running function createdrivernamelist....";
	echo "==============================================================================="
	echo "NUMBEROFDRIVERS retrieve-able from \"${nthost}\" is $NUMBEROFDRIVERS".;
	echo "  -->  If you got \"0\" you may want to run \"fetchenumdrivers3listfromNThost\""
	echo "       again. <---";
	echo "===============================================================================";
	echo " ";
	driverlist=`cat ${nthost}/completedriverlist.txt`;

	# alternative method suggested by Fabian Franz:
	# | awk 'BEGIN {n=1} { print "DRIVERNAME"n"=\""$0"\""; n=n+1 } '
}



# -----------------------------------------------------------------------------
# ----------- Create a list of all available printers -------------------------
#
# PRECONDITIONS: 1) This function expects write access to the current directory. 
#		 2) This functions expects to have the $nthosts, $printeradmin
#		    and $adminpassword variables set to according values.
# WHAT IT DOES: This function connects to the "$nthost" (using the credentials
#		$printeradmin with $adminpasswd), retrieves a list of printqueues
#		(with associated driver names) from that host, and saves the
#		list under the name of "${nthost}/printerlistwithUNCnames.txt"
#		(ie. it also creates the "$nthost" subdirectory in the current i
#		one). It further prints some more info to stdout.
# IF IT DOESN'T WORK: It may happen that the function doesn't work at the first
#		      time (there may be a connection problem). Just repeat a
#		      few times. It may work then. You will recognize if it does.
#               
#
function createprinterlistwithUNCnames()
{
	[ -d ${nthost} ] || mkdir -p ${nthost};
	echo " "
	echo " "
	echo " "
	echo "--> Running now function createprinterlistwithUNCnames()...."
	echo "===================================================================="
	rpcclient -U"${printeradmin}%${adminpasswd}" -c 'enumprinters' ${nthost} \
	| grep "description:" \
	| awk -F "[" '{ print $2 }' \
	| awk -F "]" '{ print $1 }' \
	| sort \
	| uniq \
	| tee \
	${nthost}/printerlistwithUNCnames.txt;

	NUMBEROFPRINTERS=`cat ${nthost}/printerlistwithUNCnames.txt| wc -l`;
	echo " ";
	echo "--> Finished in running function createprinterlistwithUNCnames....";
	echo "=========================================================================="
	echo "NUMBEROFPRINTERS retrieved from \"${nthost}\" is $NUMBEROFPRINTERS".;
	echo "  -->  If you got \"0\" you may want to try again. <---";
	echo "==========================================================================";
	echo " ";
	printerlistwithUNCnames=`cat ${nthost}/printerlistwithUNCnames.txt`;
}


# -----------------------------------------------------------------------------
# ----------- Create a list of all printers which have (no) drivers -----------
#
# PRECONDITIONS: 1) This function expects to find the subdirectory "$nthost" 
#		    and the file "${nthost}/printerlistwithUNCnames.txt" to exist.
#		 2) This functions expects to have the $nthosts variable set 
#		    to an according value.
# WHAT IT DOES: This function dissects the "${nthost}/printerlistwithUNCnames.txt" 
#		and creates another textfiles from its contents:
#		- "${nthost}/allprinternames.txt"
#		- "${nthost}/alldrivernames.txt"
#		- "${nthost}/allnonrawprinters.txt"
#		- "${nthost}/allrawprinters.txt"
#		- "${nthost}/printertodrivermap.txt"
#		and further prints some more info to stdout.
#
function createmapofprinterstodrivers()
{
	echo " "
	echo " "
	echo "--> Running now function createmapofprinterstodrivers()...."
	echo "==========================================================="
	echo " "
	echo " "
	echo "ALL PRINTERNAMES:"
	echo "================="
	echo " "
	cat ${nthost}/printerlistwithUNCnames.txt \
	| awk -F "\\" '{ print $4 }' \
	| awk -F "," '{print $1}' \
	| sort \
	| uniq \
	| tee \
	${nthost}/allprinternames.txt; 
	
	echo " "
	echo " "
	echo "ALL non-RAW PRINTERS:"
	echo "====================="
	echo " "
	cat ${nthost}/printerlistwithUNCnames.txt \
	| grep -v ",," \
	| awk -F "\\" '{ print $4 }' \
	| awk -F "," '{print $1}' \
	| sort \
	| uniq \
	| tee \
	${nthost}/allnonrawprinters.txt; 
	
	echo " "
	echo " "
	echo "ALL RAW PRINTERS:"
	echo "================"
	echo " "
	cat ${nthost}/printerlistwithUNCnames.txt \
	| grep ",," \
	| awk -F "\\" '{ print $4 }' \
	| awk -F "," '{print $1}' \
	| sort \
	| uniq \
	| tee \
	${nthost}/allrawprinters.txt; 
	
	echo " "
	echo " "
	echo "THE DRIVERNAMES:"
	echo "================"
	cat ${nthost}/printerlistwithUNCnames.txt \
	| awk -F "," '{print $2 }' \
	| grep -v "^$" \
	| tee \
	${nthost}/alldrivernames.txt;

	echo " "
	echo " "
	echo "THE PRINTER-TO-DRIVER-MAP-FOR-non-RAW-PRINTERS:"
	echo "==============================================="
	cat ${nthost}/printerlistwithUNCnames.txt \
	| awk -F "\\" '{ print $4 }' \
	| awk -F "," '{ print "\"" $1 "\":\"" $2 "\"" }' \
	| grep -v ":\"\"$" \
	| tee \
	${nthost}/printertodrivermap.txt 
	echo -e "##########################\n#  printer:driver  #" >> ${nthost}/printertodrivermap.txt
}


# -----------------------------------------------------------------------------
# ----------- Create a list of all printers which have drivers ----------------
#
# PRECONDITIONS: 1) This function expects to find the subdirectory "$nthost"
#		    otherwise it creates it...
# WHAT IT DOES: This function creates the "${nthost}/printernamelist.txt"
#		and prints it to <stdout>.
#
function getdrivernamelist()
{
	[ -d ${nthost} ] || mkdir -p ${nthost};
	echo " "
	echo " "
	echo "--> Running now function getdrivernamelist()...."
	echo "================================================="
	rpcclient -U${printeradmin}%${adminpasswd} -c 'enumprinters' ${nthost} \
	| grep "description:" \
	| grep -v ",," \
	| awk -F "," '{ print $2 }' \
	| sort \
	| uniq \
	| tee \
	${nthost}/drivernamelist.txt
}


# -----------------------------------------------------------------------------
# ----------- Split the driverfile listing between the architectures ----------
#
# PRECONDITIONS: 1) This function expects write access to the current directory. 
#		 2) This functions expects to have the $nthost variable set to 
#		    the according value.
# WHAT IT DOES: This function dissects the "$nthost/enumdrivers3list.txt" (using 
#		"sed", "cat", "awk" and "grep"). It splits the list up into
#		two different files representing a complete list of drivers and
#		files for each of the 2 supported architectures. 
#		It creates "{nthost}/W32X86/${nthost}-enumdrivers3list-NTx86.txt"
#		and "{nthost}/WIN40/${nthost}-enumdrivers3list-WIN40.txt".
# IF IT DOESN'T WORK: The function "fetchenumdrivers3listfromNThost" may not have
#		      been run successfully. This is a precondition for the 
#		      current function.
#               
#
function splitenumdrivers3list()
{
	echo " "
	echo " "
	echo "--> Running now function splitenumdrivers3list()...."
	echo "===================================================="
	
	[ -d ${nthost}/WIN40 ]  || mkdir -p ${nthost}/WIN40;
	[ -d ${nthost}/W32X86 ] || mkdir -p ${nthost}/W32X86;
	
	cat ${nthost}/enumdrivers3list.txt \
	| sed -e '/^\[Windows NT x86\]/,$ d' \
	| tee \
	${nthost}/WIN40/${nthost}-enumdrivers3list-WIN40.txt ;
	
	cat ${nthost}/WIN40/${nthost}-enumdrivers3list-WIN40.txt \
	| grep Version \
	| sort \
	| uniq \
	| awk -F "[" '{ print $2 }' \
	| awk -F "]" '{ print $1 }' \
	| tee ${nthost}/WIN40/availableversionsWIN40.txt ;

#	cd ${nthost}/WIN40/ ;
#	mkdir $( cat availableversionsWIN40.txt ) 2> /dev/null ;
#	cd - ;
	
	cat ${nthost}/enumdrivers3list.txt \
	| sed -e '/^\[Windows NT x86\]/,$! d' \
	| tee \
	${nthost}/W32X86/${nthost}-enumdrivers3list-NTx86.txt ;
	
	cat ${nthost}/W32X86/${nthost}-enumdrivers3list-NTx86.txt \
	| grep Version \
	| sort \
	| uniq \
	| awk -F "[" '{ print $2 }' \
	| awk -F "]" '{ print $1 }' \
	| tee ${nthost}/W32X86/availableversionsW32X86.txt ;

#	cd ${nthost}/W32X86/ ;
#	mkdir $( cat availableversionsW32X86.txt ) 2> /dev/null ;
#	cd - ;
}


# -----------------------------------------------------------------------------
# ---------- Make subdirs in ./${sambahost}/WIN40/ for each driver.... -------
#
# PRECONDITIONS: 1) These functions expects write access to the current directory. 
#		 2) These functions expects to have the $nthost variable set to 
#		    the according value.
#		 3) These functions expect to find the two files
#		    "${nthost}/WIN40/${nthost}-enumdrivers3list-WIN40.txt" and
#		    "${nthost}/W32X86/${nthost}-enumdrivers3list-NTx86.txt" to work on.
# WHAT IT DOES: These functions dissect the "$nthost/enumdrivers3list.txt" (using 
#		"sed", "cat", "awk" and "grep"). They split the input files up into
#		individual files representing driver(version)s and create
# 		appropriate subdirectories for each driver and version underneath
#		"./$nthost/<architecture>". They use the drivernames (including 
#		spaces) for the directory names. ("/" -- slashes -- in drivernames are
#		converted to underscores).
# IF IT DOESN'T WORK: The function "fetchenumdrivers3listfromNThost" and consecutive
#		      ones may not have
#		      been run successfully. This is a precondition for the 
#		      current function.
#               
#
function makesubdirsforWIN40driverlist()
{	
	cat ${nthost}/WIN40/${nthost}-enumdrivers3list-WIN40.txt \
	| grep "Driver Name:" \
	| awk -F "[" '{ print $2 }' \
	| awk -F "]" '{ print $1 }' \
	| sort \
	| uniq \
	| tr / _ \
	| sed -e 's/$/\"/' \
	| sed -e 's/^/mkdir -p '"\"${nthost}"'\/WIN40\//' \
	| tee \
	${nthost}/makesubdirsforWIN40driverlist.txt;
	
	sh -x ${nthost}/makesubdirsforWIN40driverlist.txt;

#	rm ${nthost}/makesubdirsforWIN40driverlist.txt;
}


# -----------------------------------------------------------------------------
# ---------- Make subdirs in ./${sambahost}/W32X86/ for each driver.... -------
function makesubdirsforW32X86driverlist()
{	
	cat ${nthost}/W32X86/${nthost}-enumdrivers3list-NTx86.txt \
	| grep "Driver Name:" \
	| awk -F "[" '{ print $2 }' \
	| awk -F "]" '{ print $1 }' \
	| sort \
	| uniq \
	| tr / _ \
	| sed -e 's/$/\"/' \
	| sed -e 's/^ */mkdir '\""${nthost}"'\/W32X86\//' \
	| tee \
	${nthost}/makesubdirsforW32X86driverlist.txt;
	
	sh -x ${nthost}/makesubdirsforW32X86driverlist.txt;

#	rm ${nthost}/makesubdirsforW32X86driverlist.txt;
}




# -----------------------------------------------------------------------------
# ----------- Split the WIN40 driverfile listing of each architecture ---------
# ------------------------ into individual drivers ----------------------------
function splitWIN40fileintoindividualdriverfiles()
{
	echo " "
	echo " "
	echo "--> Running now function splitWIN40fileintoindividualdriverfiles()..."
	echo "====================================================================="
	
	for i in ${nthost}/WIN40/*/; do
		CWD1="$( pwd )" ;
		cd "${i}" ;
	echo " "
	echo " "
	echo " ###########################################################################################"
	echo " "
	echo "   Next driver is \"$( basename "$( pwd)" )\""
	echo " "
	echo " ###########################################################################################"

		echo "yes" | cp -f ../../../${nthost}/WIN40/${nthost}-enumdrivers3list-WIN40.txt . 2> /dev/null ;

	tac ${nthost}-enumdrivers3list-WIN40.txt \
	| sed -e '/'"$(basename "$(echo "$PWD")")"'/,/Version/ p' -n \
	| grep Version  \
	| uniq \
	| awk -F "[" '{ print $2 }' \
	| awk -F "]" '{ print "mkdir \"" $1 "\"" }' \
	| tee mkversiondir.txt ;

	sh mkversiondir.txt 2> /dev/null ;

	cat ${nthost}-enumdrivers3list-WIN40.txt \
	| sed -e '/'"$(basename "$(echo "$PWD")")"'/,/Monitor/ w alldriverfiles.txt' -n ;

	for i in */; do 
	CWD2="$( pwd )" ;
	cd "${i}";
	echo "yes" | cp ../alldriverfiles.txt . 2> /dev/null ;

	cat alldriverfiles.txt \
	| egrep '(\\'"$(basename "$( pwd )")"'\\|Driver Name)' \
	| tee driverfilesversion.txt ;

	Drivername=$( grep "Driver Name:" driverfilesversion.txt \
	| awk -F "[" '{ print $2 }' \
	| awk -F "]" '{ print $1 }' \
	| sort \
	| uniq ) ;
	echo "${Drivername}" \
	| tee Drivername ;


	DriverPath=$( grep "Driver Path:" driverfilesversion.txt \
	| awk -F "[" '{ print $2 }' \
	| awk -F "]" '{ print $1 }' \
	| awk -F "WIN40" '{ print $2 }' \
	| awk -F "\\" '{ print $3 }'  \
	| sort \
	| uniq ) ;
	echo "${DriverPath}" \
	| tee DriverPath ;

	Datafile=$( grep "Datafile:" driverfilesversion.txt \
	| awk -F "[" '{ print $2 }' \
	| awk -F "]" '{ print $1 }' \
	| awk -F "WIN40" '{ print $2 }' \
	| awk -F "\\" '{ print $3 }' \
	| sort \
	| uniq  ) ;
	echo "${Datafile}" \
	| tee Datafile ;

	Configfile=$( grep "Configfile:" driverfilesversion.txt \
	| awk -F "[" '{ print $2 }' \
	| awk -F "]" '{ print $1 }' \
	| awk -F "WIN40" '{ print $2 }' \
	| awk -F "\\" '{ print $3 }'  \
	| sort \
	| uniq ) ;
	echo "${Configfile}" \
	| tee Configfile ;

	Helpfile=$( grep "Helpfile:" driverfilesversion.txt \
	| awk -F "[" '{ print $2 }' \
	| awk -F "]" '{ print $1 }' \
	| awk -F "WIN40" '{ print $2 }' \
	| awk -F "\\" '{ print $3 }'  \
	| sort \
	| uniq ) ;
	echo "${Helpfile}" \
	| tee Helpfile ;

	Dependentfilelist=$( grep "Dependentfiles:" driverfilesversion.txt \
	| awk -F "[" '{ print $2 }' \
	| awk -F "]" '{ print $1 }' \
	| awk -F "WIN40" '{ print $2 }' \
	| awk -F "\\" '{ print $3 }'  \
	| sort \
	| uniq ) ;

	Dependentfiles=$( echo $Dependentfilelist \
	| sed -e 's/ /,/g ' )
	echo "${Dependentfiles}" \
	| tee Dependentfiles

	AllFiles=$( echo ${Dependentfilelist}; echo ${Helpfile}; echo ${Configfile}; echo ${Datafile}; echo ${DriverPath} )
	echo "${AllFiles}" \
	| tee AllFiles ;

	cd "${CWD2}" 1> /dev/null ;
	done

#	rpcclient -U"${smbprinteradmin}%${smbadminpasswd}" \
#	-c "adddriver \"${Architecture}\" \"${DriverName}:${DriverPath}:${Datafile}:${Configfile}:${Helpfile}:NULL:RAW:${Dependentfiles}\" ${Version}" \ ${smbhost}

#	rpcclient -U"${smbprinteradmin}%${smbadminpasswd}" \
#	-c "setdriver \"${printername}\" \"${DriverName}\"" \
#	${smbhost}
#
#	rpcclient -U"${smbprinteradmin}%${smbadminpasswd}" \
#	-c "setprinter \"${printername}\" \"Driver was installed and set via MS-RPC (utilized by Kurt Pfeifle\'s set of \"Vampire Printerdrivers\" scripts from Linux)\"" \
#	${smbhost}

	cd "${CWD1}" 1> /dev/null ;
	done;
}




# -----------------------------------------------------------------------------
# ---------- Split the W32X86 driverfile listing of each architecture ---------
# ------------------------ into individual drivers ----------------------------
function splitW32X86fileintoindividualdriverfiles()
{
	echo " "
	echo " "
	echo "--> Running now function splitW32X86fileintoindividualdriverfiles()..."
	echo "====================================================================="
	
	for i in ${nthost}/W32X86/*/; do
		CWD1="$( pwd )" ;
		cd "${i}" ;
	echo " "
	echo " "
	echo " ###########################################################################################"
	echo " "
	echo "   Next driver is \"$( basename "$( pwd)" )\""
	echo " "
	echo " ###########################################################################################"

		echo "yes" | cp -f ../../../${nthost}/W32X86/${nthost}-enumdrivers3list-NTx86.txt . 2> /dev/null ;

	tac ${nthost}-enumdrivers3list-NTx86.txt \
	| sed -e '/'"$(basename "$(echo "$PWD")")"'/,/Version/ p' -n \
	| grep Version  \
	| uniq \
	| awk -F "[" '{ print $2 }' \
	| awk -F "]" '{ print "mkdir \"" $1 "\"" }' \
	| tee mkversiondir.txt ;

	sh mkversiondir.txt 2> /dev/null ;

	cat ${nthost}-enumdrivers3list-NTx86.txt \
	| sed -e '/'"$(basename "$(echo "$PWD")")"'/,/Monitor/ w alldriverfiles.txt' -n ;

	for i in */; do 
	CWD2="$( pwd )" ;
	cd "${i}";
	echo "yes" | cp ../alldriverfiles.txt . 2> /dev/null ;

	cat alldriverfiles.txt \
	| egrep '(\\'"$(basename "$( pwd )")"'\\|Driver Name)' \
	| tee driverfilesversion.txt ;

	Drivername=$( grep "Driver Name:" driverfilesversion.txt \
	| awk -F "[" '{ print $2 }' \
	| awk -F "]" '{ print $1 }' \
	| sort \
	| uniq ) ;
	echo "${Drivername}" \
	| tee Drivername ;


	DriverPath=$( grep "Driver Path:" driverfilesversion.txt \
	| awk -F "[" '{ print $2 }' \
	| awk -F "]" '{ print $1 }' \
	| awk -F "W32X86" '{ print $2 }' \
	| awk -F "\\" '{ print $3 }'  \
	| sort \
	| uniq ) ;
	echo "${DriverPath}" \
	| tee DriverPath ;

	Datafile=$( grep "Datafile:" driverfilesversion.txt \
	| awk -F "[" '{ print $2 }' \
	| awk -F "]" '{ print $1 }' \
	| awk -F "W32X86" '{ print $2 }' \
	| awk -F "\\" '{ print $3 }' \
	| sort \
	| uniq  ) ;
	echo "${Datafile}" \
	| tee Datafile ;

	Configfile=$( grep "Configfile:" driverfilesversion.txt \
	| awk -F "[" '{ print $2 }' \
	| awk -F "]" '{ print $1 }' \
	| awk -F "W32X86" '{ print $2 }' \
	| awk -F "\\" '{ print $3 }'  \
	| sort \
	| uniq ) ;
	echo "${Configfile}" \
	| tee Configfile ;

	Helpfile=$( grep "Helpfile:" driverfilesversion.txt \
	| awk -F "[" '{ print $2 }' \
	| awk -F "]" '{ print $1 }' \
	| awk -F "W32X86" '{ print $2 }' \
	| awk -F "\\" '{ print $3 }'  \
	| sort \
	| uniq ) ;
	echo "${Helpfile}" \
	| tee Helpfile ;

	Dependentfilelist=$( grep "Dependentfiles:" driverfilesversion.txt \
	| awk -F "[" '{ print $2 }' \
	| awk -F "]" '{ print $1 }' \
	| awk -F "W32X86" '{ print $2 }' \
	| awk -F "\\" '{ print $3 }'  \
	| sort \
	| uniq ) ;

	Dependentfiles=$( echo $Dependentfilelist \
	| sed -e 's/ /,/g ' )
	echo "${Dependentfiles}" \
	| tee Dependentfiles

	AllFiles=$( echo ${Dependentfilelist}; echo ${Helpfile}; echo ${Configfile}; echo ${Datafile}; echo ${DriverPath} )
	echo "${AllFiles}" \
	| tee AllFiles ;

	cd "${CWD2}" 1> /dev/null ;
	done

#	rpcclient -U"${smbprinteradmin}%${smbadminpasswd}" \
#	-c "adddriver \"${Architecture}\" \"${DriverName}:${DriverPath}:${Datafile}:${Configfile}:${Helpfile}:NULL:RAW:${Dependentfiles}\" ${Version}" \ ${smbhost}

#	rpcclient -U"${smbprinteradmin}%${smbadminpasswd}" \
#	-c "setdriver \"${printername}\" \"${DriverName}\"" \
#	${smbhost}
#
#	rpcclient -U"${smbprinteradmin}%${smbadminpasswd}" \
#	-c "setprinter \"${printername}\" \"Driver was installed and set via MS-RPC (utilized by Kurt Pfeifle\'s set of \"Vampire Printerdrivers\" scripts from Linux)\"" \
#	${smbhost}

	cd "${CWD1}" 1> /dev/null ;
	done;
}



# -----------------------------------------------------------------------------
# ------------------ First download the driverfiles........... ----------------
#
# PRECONDITIONS: 1) These functions expects write access to the current directory. 
#		 2) These functions expects to have the $nthost variable set to 
#		    the according value.
#		 3) These functions expect to find the file "AllFiles" in each of
#		    the visited subdirs ("AllFiles" must have been created by 
#		    functions "splitW32X86fileintoindividualdriverfiles" and
#		    "splitWIN40fileintoindividualdriverfiles", respectively...
# WHAT IT DOES: These functions use "smbclient" to connect to the NT print server
#		"$nthost" and download the printer driver files from there. To
#		achieve that in an orderly fashion, the previously created subdirectories
#		(named like the drivers to fetch) are visited in turn and the related
#		files are downloaded for each driver/directory.
# IF IT DOESN'T WORK: The function "fetchenumdrivers3listfromNThost" and consecutive
#		      ones may not have been run successfully. This is a precondition 
#		      for the current function.
#               
function fetchtheW32X86driverfiles()
{
	echo " "
	echo " "
	echo "--> Running now function fetchtheW32X86driverfiles()...."
	echo "======================================================="

	CURRENTWD=${PWD} ;
	for i in ${nthost}/W32X86/*/*/ ; do \
	cd "${i}"; 
	
	driverversion="$(basename "$(echo "$PWD")")" ;
	AllFiles=$( cat AllFiles ) ;
	[ -d TheFiles ] || mkdir TheFiles; 
	cd TheFiles;
	echo " "
	echo "===================================================="
	echo "Downloading files now to ${PWD}....";
	echo "===================================================="
	echo " "
	# Fetch the Driver files from the Windoze box (printserver)
	smbclient -U"${printeradmin}%${adminpasswd}" -d 2 \
	//${nthost}/print\$ -c \
	"cd W32X86\\${driverversion};prompt;mget ${AllFiles}"
	cd ${CURRENTWD} ;

	done ;
}

# -----------------------------------------------------------------------------
# -------------- Now upload the driverfiles and activate them! ----------------
# Upload the files into the root "Architecture" directory of Samba'a [print$] share...

function uploadallW32X86drivers()
{
	echo " "
	echo " "
	echo "--> Running now function uploadtheW32X86driver()...."
	echo "===================================================="
	
	for i in ${nthost}/W32X86/*/*/; do \
	CURRENTWD=${PWD} ;
	cd "${i}";
							# we are now in [..]/W32X86/[drvrname]/[2|3]/ 
	
	driverversion="$(basename "$(echo "$PWD")")" ;
	cd TheFiles ;
							# we are now in [..]/W32X86/[drvrname]/[2|3]/TheFiles
	echo " "
	echo "===================================================="
	echo "Uploading driverfiles now from ${PWD}....";
	echo "===================================================="
	echo " "
	set -x ;
	smbclient -U"${smbprinteradmin}%${smbadminpasswd}" -d 2 \
	//${smbhost}/print\$ \
	-c "mkdir W32X86;cd W32X86;prompt;mput $( cat ../AllFiles )";
	cd .. ;
							# we are now in [..]/W32X86/[drvrname]/[2|3]/ 

# Now tell Samba that those files are *printerdriver* files....
# The "adddriver" command will move them to the "0" subdir and create or
# update the associated *.tdb files (faking the MS Windows Registry on Samba)
	Drivername="$( cat Drivername )"
	set -x ;
	rpcclient -U"${smbprinteradmin}%${smbadminpasswd}" -d 2 \
	-c "adddriver \"Windows NT x86\" \"$( cat Drivername ):$( cat DriverPath ):$( cat Datafile ):$( cat Configfile ):$( cat Helpfile ):NULL:RAW:$( cat Dependentfiles )\" ${driverversion}" \
	${smbhost} ;

# Now tell Samba which printqueue this driver is associated with....
# The "setdriver" command will do just that and create or
# update the associated *.tdb files (faking the MS Windows Registry on Samba)
#	rpcclient -U"${smbprinteradmin}%${smbadminpasswd}" \
#	-c "setdriver \"${printername}\" \"${DriverName}\"" \
#	${smbhost}

# Now set a nice printer comment and let the world know what we've done
# (or not.... ;-)
#	rpcclient -U"${smbprinteradmin}%${smbadminpasswd}" \
#	-c "setprinter \"${printername}\" \"Driver was installed and set via MS-RPC (rpcclient commandline from Linux)\"" \
#	${smbhost}
	
	cd ${CURRENTWD} ;
							# we are now back to where we started
	done;
	set +x ;
}



# -----------------------------------------------------------------------------
# ------------------ First download the driverfiles........... ----------------

function fetchtheWIN40driverfiles()
{
	echo " "
	echo " "
	echo "--> Running now function fetchtheWIN40driverfiles()...."
	echo "======================================================="

	CURRENTWD=${PWD} ;
	for i in ${nthost}/WIN40/*/*/; do \
	cd "${i}"; 
	
	driverversion="$(basename "$(echo "$PWD")")" ;
	AllFiles=$( cat AllFiles ) ;
	[ -d TheFiles ] || mkdir TheFiles; 
	cd TheFiles;
	echo " "
	echo "===================================================="
	echo "Downloading files now to ${PWD}....";
	echo "===================================================="
	echo " "
	# Fetch the Driver files from the Windoze box (printserver)
	smbclient -U"${printeradmin}%${adminpasswd}" -d 2 \
	//${nthost}/print\$ -c \
	"cd WIN40\\${driverversion};prompt;mget ${AllFiles}"
	cd ${CURRENTWD} ;

	done ;
}


# -----------------------------------------------------------------------------
# -------------- Now upload the driverfiles and activate them! ----------------
# Upload the files into the root "Architecture" directory of Samba'a [print$] share...

function uploadallWIN40drivers()
{
	echo " "
	echo " "
	echo "--> Running now function uploadtheWIN40driver()...."
	echo "==================================================="
	
	for i in ${nthost}/WIN40/*/*/; do \
	CURRENTWD=${PWD} ;
	cd "${i}" ; 
							# we are now in [..]/WIN40/[drvrname]/[0]/
	
	driverversion="$(basename "$(echo "$PWD")")" ;
	cd TheFiles ;
							# we are now in [..]/WIN40/[drvrname]/[0]/TheFiles
	echo " "
	echo "===================================================="
	echo "Uploading driverfiles now from ${PWD}....";
	echo "===================================================="
	echo " "
	set -x ;
	smbclient -U"${smbprinteradmin}%${smbadminpasswd}" -d 2 \
	//${smbhost}/print\$ \
	-c "mkdir WIN40;cd WIN40;prompt;mput $( cat ../AllFiles )";
	cd .. ;
							# we are now in [..]/WIN40/[drvrname]/[0]/

# Now tell Samba that those files are *printerdriver* files....
# The "adddriver" command will move them to the "0" subdir and create or
# update the associated *.tdb files (faking the MS Windows Registry on Samba)
	Drivername="$( cat Drivername )"
	set -x ;
	rpcclient -U"${smbprinteradmin}%${smbadminpasswd}" -d 2 \
	-c "adddriver \"Windows 4.0\" \"$( cat Drivername ):$( cat DriverPath ):$( cat Datafile ):$( cat Configfile ):$( cat Helpfile ):NULL:RAW:$( cat Dependentfiles )\" ${driverversion}" \
	${smbhost} ;
	set +x ;

# Now tell Samba which printqueue this driver is associated with....
# The "setdriver" command will do just that and create or
# update the associated *.tdb files (faking the MS Windows Registry on Samba)
#	rpcclient -U"${smbprinteradmin}%${smbadminpasswd}" \
#	-c "setdriver \"${printername}\" \"${DriverName}\"" \
#	${smbhost}

# Now set a nice printer comment and let the world know what we've done
# (or not.... ;-)
#	rpcclient -U"${smbprinteradmin}%${smbadminpasswd}" \
#	-c "setprinter \"${printername}\" \"Driver was installed and set via MS-RPC (rpcclient commandline from Linux)\"" \
#	${smbhost}
	
	cd ${CURRENTWD} ;
							# we are now back to where we started
	done;
}

