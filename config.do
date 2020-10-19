* **********************************************************************
* Project:          Oolu
* Created:          20201019
* Last modified:    20201019 by et
* Stata v.16.1
* **********************************************************************
* does
    /*  Defines path names and sets some key preferences
    */

* TO DO:
    *

* **********************************************************************
* 0 - Define root folder globals
* **********************************************************************
    if "$user" == "et" {
        global myDocs "C:/Users/`c(username)'/Desktop/git"
		if "`c(username)'"=="btje4229" {
			global dropbox ///
			"C:/Users/`c(username)'/Dropbox (Personal)"
		}
		else{
			global dropbox "C:/Users/Emilia/Dropbox"
		}
    }


* **********************************************************************
* 1 - Sub-directory globals
* **********************************************************************
* Create some sub-folder globals
    global projectFolder          "${myDocs}/Oolu"
    global dataWork               "${projectFolder}/dataWork"
    global data                   "${dataWork}/data"
    global scripts                "${dataWork}/scripts"
    global logs                   "${scripts}/logs"

* Create files if don't exist
  qui: capture mkdir       "${dataWork}"
  qui: capture mkdir       "${scripts}"
  qui: capture mkdir       "${logs}"

* **********************************************************************
* 2 - Change ado directory so packages get installed in
*     a project-specific directory
* **********************************************************************
* Create ado folder if it doesn't exist
    qui: capture mkdir      "${projectFolder}/ado"
    sysdir set PERSONAL     "${projectFolder}/ado/personal"
    sysdir set PLUS         "$projectFolder/ado/plus"

* **********************************************************************
* 3 - Set important preferences
* **********************************************************************
* Set varabbrev off
    set varabbrev       off
    set more            off
    set logtype         text    // so logs can be opened without Stata

* **********************************************************************
* 4 - Start log file
* **********************************************************************
* String with current date
    local c_date    = c(current_date)
    local cdate     = subinstr("`c_date'", " ", "_", .)

* Start log file
    * generate log folder if it doesn't exist
    qui: capture mkdir  "${logs}"
    log using           "${logs}/logfile_`cdate'.log", replace text

* Note which flavor of Stata
    local variant = cond(c(MP),"MP",cond(c(SE),"SE",c(flavor)) )

* Include in log file info on how and when program was run
    di "=== SYSTEM DIAGNOSTICS ==="
    di "Stata version: `c(stata_version)'"
    di "Updated as of: `c(born_date)'"
    di "Variant:       `variant'"
    di "Processors:    `c(processors)'"
    di "OS:            `c(os)' `c(osdtl)'"
    di "Machine type:  `c(machine_type)'"
    di "=========================="
