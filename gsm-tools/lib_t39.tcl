# -*- tcl -*-
# $Id: lib_t39.tcl,v 1.5 2002/10/17 17:44:21 grigory Exp $

namespace eval phonelib {
    variable INIT_STR {atze=0}
    variable INIT_PHONE [list \
			     {at+cpms="ME","ME","ME"} \
			     {at+cnmi=3,3,2,0,0} \
			     {at+cpbs="ME"} \
			     {at+cscs="UTF-8"} \
			     {at*ecam=1}
			]  #at+crc=1  at+cr=1
    variable ring_str {RING|\*ECAV}
    variable cmd_busy   at*evh
    variable cmd_answer at*eva
    variable cmd_call   at*evd

    proc voice_call {number} {
	variable cmd_call
	return [send_data "$cmd_call=\"$number\""]
    }

    proc phone_model {} {
	regsub -all {OK|\n|\"| } [send_data ati0] {} model
	puts "Phone model: $model"
	return $model
    }

    proc reg_number {str} {
	if  {[regexp {\*ECAV: [0-9],6,} $str]} {
	    regsub -all {\n|\r|\"|^.*\*ECAV: } $str {} str
	    set str [split $str ,]
	    set res [list [lindex $str 5] [lindex $str 6]]
	    puts $res
	    return $res
	}
	return -1
    }
}
