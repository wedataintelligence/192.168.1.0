# -*- tcl -*-
# $Id: lib_simens.tcl,v 1.4 2002/10/17 17:44:21 grigory Exp $

namespace eval phonelib {
    variable INIT_STR {atze0}
    variable INIT_PHONE [list \
			     {at+cpms="ME","ME","ME"} \
			     {at+cnmi=1,1,2,2,1} \
			     {at+cpbs="ME"} \
			     {at+cscs="UCS2"} \
			     {at+clip=1}
			]
    variable ring_str {RING|\+CLIP}
    variable cmd_busy   ath
    variable cmd_answer ata
    variable cmd_call   atd

    proc voice_call {number} {
	variable cmd_call
	return [send_data "$cmd_call=\"$number\"\;"]
    }

    proc phone_model {} {
	regsub -all {OK|\n|\"| } [send_data ati9] {} model
	puts "Phone model: $model"
	return $model
    }

    proc reg_number {str} {
	if  {[regexp {\+CLIP: } $str]} {
	    regsub -all {\n|\r|\"|^.*\+CLIP: } $str {} str
	    set str [split $str ,]
	    set res [list [lindex $str 0] [lindex $str 1]]
	    return $res
	}
	return -1
    }
}
