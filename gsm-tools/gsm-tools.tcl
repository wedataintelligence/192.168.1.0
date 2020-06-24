#!/usr/bin/tclsh
# -*- tcl -*-
# $Id: gsm-tools.tcl,v 1.4 2002/10/17 17:49:14 grigory Exp $

set auto_path [linsert $auto_path 0 [file dirname [info script]]]

package require smslib
package require phonebooklib

proc SetDefaults {} {
    set ::PORT  /dev/ttyS0
    set ::SPEED 115200
    set ::DEF_NUMBER {}
    set ::language 0
    
    set ::CFGDIR          ~/.gsm-tools
    set ::ConfigFile      $::CFGDIR/config
    set ::RecivedFile     $::CFGDIR/recived.log
    set ::IncomingCallLog $::CFGDIR/incoming_call.log
    set ::PhoneBookFile   $::CFGDIR/phone_book.dat

    set ::PWD_DIR [file dirname [info script]]

    switch $::tcl_platform(platform) {
        unix { 
	    set ::LIBS [list $::PWD_DIR /usr/share/tcl/gsm-tools]
	}
        windows {
	    if {[info exists ::env(USERPROFILE)]} {
		set ::BASE [file join $::env(USERPROFILE) gsm-tools]
	    } else { set ::BASE $mydir }
	    set ::LIBS [list $::PWD_DIR $::BASE]
	}
    }
}

proc load_lib {libname} {
    foreach path $::LIBS {if {[file exists $path/$libname]} {source $path/$libname; break}}
}

SetDefaults
source $::ConfigFile
load_lib phonelib.tcl
load_lib lib_$::MODEL.tcl

proc if_gui {} {
    if {[string match $::use_gui TK]} {return true}
    return false
}

#------------------------------------------------------------
proc stdin_read {} {
    set in_data [gets stdin]
    if {[regexp {^quit} $in_data]} {set ::forever 1} else {puts [phonelib::send_data $in_data]}
}
fileevent stdin readable stdin_read
#------------------------------------------------------------


proc log {file message} {
    set f [open $file a+];
    puts $f "\[[clock format [clock seconds] -format {%Y/%m/%d %T}]\]: $message"
    close $f
}


# Initialize module
phone::init_phonebook
if {![if_gui]} {vwait ::forever} else {load_lib gui.tcl}
