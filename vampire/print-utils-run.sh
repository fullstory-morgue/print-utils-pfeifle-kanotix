#!/bin/bash
source /usr/share/print-utils-pfeifle-kanotix/functions-to-get-drivers.sh
source xp_nthost_knoppix_smbhost
fetchenumdrivers3listfromNThost      # repeat, if no success at first
createdrivernamelist 
createprinterlistwithUNCnames       # repeat, if no success at first
createmapofprinterstodriver
splitenumdrivers3list
makesubdirsforW32X86driverlist
splitW32X86fileintoindividualdriverfiles
fetchtheW32X86driverfiles
uploadallW32X86drivers
makesubdirsforWIN40driverlist
splitWIN40fileintoindividualdriverfiles
fetchtheWIN40driverfiles
uploadallWIN40drivers
