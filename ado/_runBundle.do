********************************************************************************
***  Master run bundle 
***
***
**
**
**
**
**
**
**

args request remoteDir nrep jobname jobID callBack email nodes ppn pmem walltime wFName cFName mFName argPass monInstructions


********************************************************************************
*** Define functions
********************************************************************************

************************
*** MASTER submission program 

capture program drop _submitMaster
program define _submitMaster
	
	args remoteDir nrep jobname callBack email nodes ppn pmem walltime wFName cFName mFName argPass 
	
	*** Compose the master submit 
	local masterHeader  "cd `remoteDir'/logs`=char(10)'qsub << \EOF1`=char(10)'#PBS -N mas_`jobname'`=char(10)'#PBS -S /bin/bash`=char(10)'"
	local masterResources  "#PBS -l nodes=1:ppn=1,pmem=1gb,walltime=12:00:00`=char(10)'"
	local spoolerHeader "cd `remoteDir'/logs`=char(10)'qsub << \EOF2`=char(10)'#PBS -N spo_`jobname'`=char(10)'#PBS -S /bin/bash`=char(10)'"
	local spoolerResources "#PBS -l nodes=1:ppn=1,pmem=1gb,walltime=120:00:00`=char(10)'"
	local spoolerWork "cd `remoteDir'/logs`=char(10)'module load stata/15`=char(10)'stata-mp -b `remoteDir'/scripts/_runBundle.do spool `remoteDir' `nrep' `jobname' 0 `callBack' `email' `nodes' `ppn' `pmem' `walltime' `wFName' 0 0 `argPass'`=char(10)'"
	local spoolerTail "EOF2`=char(10)'"
	local monitorHeader "cd `remoteDir'/logs`=char(10)'qsub << \EOF3`=char(10)'#PBS -N mon_`jobname'`=char(10)'#PBS -S /bin/bash`=char(10)'"
	local monitorResources "#PBS -l nodes=1:ppn=1,pmem=1gb,walltime=120:00:00`=char(10)'"
	local monitorEmail "#PBS -m e`=char(10)'#PBS -M `email'`=char(10)'"
	local monitorWork "cd `remoteDir'/logs`=char(10)'module load stata/15`=char(10)'module load moab`=char(10)'stata-mp -b `remoteDir'/scripts/_runBundle.do monitor `remoteDir' `nrep' `jobname' 0 `callBack' `email' `nodes' `ppn' `pmem' `walltime' `wFName' `cFName' `mFName' `argPass'`=char(10)'"
	local monitorTail "EOF3`=char(10)'"
	local masterTail "EOF1`=char(10)'"

	*** Combine all parts 
	if "`email'" == "0" {
		local masterFileContent "`masterHeader'`masterResources'`spoolerHeader'`spoolerResources'`spoolerWork'`spoolerTail'`monitorHeader'`monitorResources'`monitorWork'`monitorTail'`masterTail'"
	}
	else {
		local masterFileContent "`masterHeader'`masterResources'`spoolerHeader'`spoolerResources'`spoolerWork'`spoolerTail'`monitorHeader'`monitorResources'`monitorEmail'`monitorWork'`monitorTail'`masterTail'"
	}
	
	*** Initialize a filename and a temp file
	tempfile mSubmit
	tempname mfName

	*** Write out the content to the file
	file open `mfName' using `mSubmit', write text replace
	file write `mfName' `"`masterFileContent'"'
	file close `mfName'

	*** Submit the job
	shell cat `mSubmit' | bash -s

end


************************
*** WORK submission program

capture program drop _submitWork
program define _submitWork, sclass

	args remoteDir jobname nodes ppn pmem walltime wFName monInstructions
	
	*** Compose the submit file
	local pbsHeader "cd `remoteDir'/logs`=char(10)'qsub << \EOF`=char(10)'#PBS -N wor_`jobname'`=char(10)'#PBS -S /bin/bash`=char(10)'"
	local pbsResources "#PBS -l nodes=`nodes':ppn=`ppn',pmem=`pmem',walltime=`walltime'`=char(10)'"
	local pbsCommands "module load stata/15`=char(10)'cd `remoteDir'/logs`=char(10)'"
	local pbsDofile "stata-mp -b `remoteDir'/scripts/_runBundle.do work `remoteDir' 0 na $"  // this is written like this so that Stata can write it properly!
	local pbsEnd `"PBS_JOBID 0 0 0 0 0 0 `wFName' 0 0 0 "`monInstructions'"`=char(10)'EOF`=char(10)'"'
	
	*** Combine all parts
	local pbsFileContent `"`pbsTitle'`pbsHeader'`pbsResources'`pbsCommands'`pbsDofile'"'

	*** Initialize a filename and a temp file
	tempfile pbsSubmit
	tempname myfile
	
	*** Write out the content to the file
	file open `myfile' using `pbsSubmit', write text replace
	file write `myfile' `"`pbsFileContent'"'
	file write `myfile' `"`pbsEnd'"'
	file close `myfile'

	*** Submit to sirius
	shell cat `pbsSubmit' | bash -s
end


**** Process checker program
capture program drop _waitAndCheck
program define _waitAndCheck

	args sleepTime jobname
	
	sleep `sleepTime'
	ashell showq -n | grep `jobname' | wc -l   // install ashell
	
	while `r(o1)' ~= 0 {
		sleep `sleepTime'
		ashell showq -n | grep `jobname' | wc -l
	}
	
end


************************
*** WORK COLLECTION program

capture program drop _collectWork
program define _collectWork, sclass

	args remoteDir jobname cFName argPass
	
	*** Compose the submit file
	local pbsHeader "cd `remoteDir'/logs`=char(10)'qsub << \EOF`=char(10)'#PBS -N col_`jobname'`=char(10)'#PBS -S /bin/bash`=char(10)'"
	local pbsResources "#PBS -l nodes=1:ppn=4,pmem=10gb,walltime=120:00:00`=char(10)'"
	local pbsCommands "module load stata/15`=char(10)'cd `remoteDir'/logs`=char(10)'"
	local pbsDofile "stata-mp -b `remoteDir'/scripts/_runBundle.do collect `remoteDir' 0 `jobname' 0 0 0 0 0 0 0 0 `cFName' 0 `argPass'"
	local pbsEnd "`=char(10)'EOF`=char(10)'"
	
	*** Combine all parts
	local pbsFileContent `"`pbsTitle'`pbsHeader'`pbsResources'`pbsCommands'`pbsDofile'"'

	*** Initialize a filename and a temp file
	tempfile pbsSubmit
	tempname myfile
	
	*** Write out the content to the file
	file open `myfile' using `pbsSubmit', write text replace
	file write `myfile' `"`pbsFileContent'"'
	file write `myfile' `"`pbsEnd'"'
	file close `myfile'

	*** Submit to sirius
	shell cat `pbsSubmit' | bash -s
end



*** Callback input converter
capture program drop _cbTranslate
program define _cbTranslate, sclass

	args callback
	
	if regexm("`callback'", "([0-9]+)([smhd])") {
		local duration "`=regexs(1)'"
		local unit "`=regexs(2)'"
		
		if "`unit'" == "s" {
			local len = `duration' * 1000
		}
		else if "`unit'" == "m" {
			local len = `duration' * 60000
		}
		else if "`unit'" == "h" {
			local len = `duration' * 3600000
		}
		else if "`unit'" == "d" {
			local len = `duration' * 86400000
		}
	}
	else {
		noi di in r "Incorrectly specified callback option"
		exit 489
	}
	
	sreturn local lenSleep "`len'"
	
end





********************************************************************************
*** Program code
********************************************************************************

if "`request'" == "master" {
	_submitMaster "`remoteDir'" "`nrep'" "`jobname'" "`callBack'" "`email'" "`nodes'" "`ppn'" "`pmem'" "`walltime'" "`wFName'" "`cFName'" "`mFName'" "`argPass'"
	
}	
else if "`request'" == "spool" {
	forval i=1/`nrep' { 
		_submitWork "`remoteDir'" "`jobname'" "`nodes'" "`ppn'" "`pmem'" "`walltime'" "`wFName'"
	}
}
else if "`request'" == "work" {
	do "`remoteDir'/scripts/imports/`wFName'" "`jobID'"
}
else if "`request'" == "monitor" {

	// IMPORT code for monitoring
	include "`remoteDir'/scripts/imports/`mFName'" 
	
}
else if "`request'" == "collect" {
	
	// IMPORT code for output collection
	include "`remoteDir'/scripts/imports/`cFName'" 
}
else {
	noi di in r "Invalid request"
	exit 489
}

exit






