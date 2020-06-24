# -*- tcl -*-
# $Id: phonelib.tcl,v 1.16 2002/10/17 16:48:40 grigory Exp $

# if {$::tcl_platform(platform) == "windows"} {set DEVICE_PORT com4:}

proc error_ex {str} {
    puts "Error: $str"
    exit
}

namespace eval phonelib {
    variable PORT {}
    variable SPEED {}
    variable INIT_STR {}
    variable INIT_PHONE {}
    variable PHONE_MODEL {}

    variable f_phone {}
    variable f_phone_stat 0
    variable data {}
    variable rx_buf {}
    variable data_sended {}
    variable ring_str {}
}

proc phonelib::initialize {} {
    variable f_phone
    variable PHONE_MODEL
    if {($f_phone == {}) || ![regexp {OK} [send_data at]]} {
	puts "Initializing..."
	close_port
	open_port $::PORT $::SPEED
	init_phone
	set num [operator_number]
	smslib::set_oper_number [lindex $num 0] [lindex $num 1]
	set PHONE_MODEL [phone_model]
	if {[if_gui]} {GUI::update}
    }
    after 60000 phonelib::initialize
}

proc phonelib::read_port {f} {
    variable rx_buf
    variable data_sended
    variable ring_str
    if {[eof $f]} { return }
    while {[string len [set buf [gets $f]]]} {
	append rx_buf $buf "\n"
	if {[regexp -all {OK|ERROR|>} $buf]} {
	    set data_sended 1
	} elseif {[regexp -all {\+CMT: [0-9]+\n[0-9ABCDEF]+} $rx_buf]} {
	    regsub -all {^.*\+CMT: [0-9]+\n} $buf {} sms
	    regsub -all {\n} $sms {} sms
	    puts "Recieve SMS:\n$sms\n==========="
	    set sms [smslib::decode_sms $sms]
	    log $::RecivedFile $sms
	    if {[if_gui]} {after 0 "GUI::show_recived_msg [list $sms]"}
	    set rx_buf {}
	} elseif {[regexp -all $ring_str $buf]} {
	    puts "call/recieve: $rx_buf"
	    if {[set num [reg_number $rx_buf]] != -1} {
		set number [lindex $num 0]; set type [lindex $num 1]
		if {[string length $number] == 0} {set number Unknown}
		log $::IncomingCallLog "$number $type"
		if {[if_gui]} {after 0 "GUI::show_incoming_call $number $type"}
	    }
	    set rx_buf {}
	}
    }
}

proc phonelib::write_port {f} {
    variable data
    variable data_sended
    variable rx_buf
    if {[eof $f]} {set data_sended -1; return }
    if {[string len $data]} {
	set rx_buf {}
	if {$data != "at"} {puts "\nSend: '$data'"}
	puts $f "$data"
	fileevent $f writable {}
    }
}

proc phonelib::open_port {port speed} {
    variable f_phone
    variable f_phone_stat
    variable PORT $port
    variable SPEED $speed
    if {$f_phone_stat > 0} { return }
    puts "Open port."
    set f_phone [open $PORT r+]
    fconfigure $f_phone -mode $SPEED,n,8,1 -encoding utf-8 -buffering none -blocking off -translation crlf
    fileevent $f_phone readable [list [namespace current]::read_port $f_phone]
    set f_phone_stat 1
}

proc phonelib::init_phone {} {
    variable f_phone
    variable INIT_STR
    variable INIT_PHONE
    set ret 10
    puts "Init phone."
    if {$::tcl_platform(platform) == "windows"} {after 1000}
    puts $f_phone $INIT_STR
    while {![regexp -all {OK} [gets $f_phone]] || ($ret < 0)} {incr ret -1; after 500}
    if {$ret <= 0} {error_ex "Phone init error."} else {
	foreach init_str $INIT_PHONE {puts [send_data $init_str]}
    }
}

proc phonelib::close_port {} {
    variable f_phone
    variable f_phone_stat
    if {$f_phone_stat > 0} {
	puts "Exit."
	catch {close $f_phone}
	set f_phone_stat 0
    }
}

proc phonelib::send_data {send_command} {
    variable data
    variable f_phone
    variable rx_buf
    variable data_sended {}

    set data $send_command
    if {![catch {fileevent $f_phone writable [list [namespace current]::write_port $f_phone]}]} {
	set aft [after 30000 "set [namespace current]::data_sended -1"]
	vwait phonelib::data_sended
	after cancel $aft
	if {$data_sended < 0} {puts "Sending error..."; return $data_sended}
	set res $rx_buf
	set rx_buf {}
	return $res
    }
    return -1
}

proc phonelib::melodies {} {
    set new_lst {}
    set melodies_str [send_data at*esom?]
    regsub -all {\*ESOM:|OK\n|\"} $melodies_str {} melodies_str
    set lst [split $melodies_str "\n"]
    for {set i 0} {$i<[llength $lst]} {incr i} {
	if {[string length [lindex $lst $i]]} {lappend new_lst [split [lindex $lst $i] ,]}
    }
    return $new_lst
}

proc phonelib::play_melody {num} {
    return [send_data at*erip=3,[expr $num + 30]]
}

proc phonelib::write_melody {numer melody} {
    regsub -all {\n} $melody {} melody
    return [send_data at*esom=$numer,\"$melody\",0]
}

proc phonelib::operator_number {} {
    regsub -all {\+CSCA:|OK|\n|\"| } [send_data at+csca?] {} number
    return [split $number ,]
}

proc phonelib::read_all_sms {} {
    set msgs {}
    set msg {}
    foreach sms [split [send_data at+cmgl=1] "\n"] {
	if {[regexp {\+CMGL:} $sms]} {
	    if {$msg != {}} {lappend msgs $msg}
	    regsub {\+CMGL: |\n} $sms {} msg
	} elseif {[regexp {^[0-9]} $sms]} {
	    lappend msg [smslib::decode_sms $sms]
	}
    }
    if {$msg != {}} {lappend msgs $msg}
    return $msgs
}

proc phonelib::voice_answer {} {
    return [send_data $phonelib::cmd_answer]
}

proc phonelib::voice_busy {} {
    return [send_data $phonelib::cmd_busy]
}

proc phonelib::read_number {index} {
    set numbers [send_data at+cpbr=$index]
    set phones {}
    foreach number [split $numbers "\n"] {
	if {[regexp {^\+CPBR: } $number]} {
	    regsub -all {\+CPBR: |\"} $number {} number
	    lappend phones [split $number ,]
	}
    }
    return $phones
}

proc phonelib::read_all_numbers {} {
    set book_info [send_data at+cpbr=?]
    if {[string length $book_info] < 2} {puts {Error.}; return {}}
    puts "Reading phone book from phone."
    regsub -all {\+CPBR: |\n.+|\(|\)} $book_info {} book_info
    set book_info [split $book_info ,]
    set book_size [split [lindex $book_info 0] -]
    puts "Book size: min=[lindex $book_size 0] max=[lindex $book_size 1]"
    set phone_book {}
    set min [lindex $book_size 0]
    set max [lindex $book_size 1]
    for {set i $min} {$i<$max} {incr i +100} {
	set j [expr $i + 99]
	if {$j > $max} {set j $max}
	set block [read_number $i,$j]
	foreach number $block {lappend phone_book $number}
    }
    return $phone_book
}

# Initialize module
after 500 phonelib::initialize
