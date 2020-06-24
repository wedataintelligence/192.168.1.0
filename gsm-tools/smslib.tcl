# -*- tcl -*-
# $Id: smslib.tcl,v 1.4 2002/10/17 16:48:40 grigory Exp $

package provide smslib 0.2

namespace eval smslib {
    variable OPER_ADDR_LEN  7
    variable OPER_ADDR_TYPE {}
    variable OPER_NUMBER    {}
    variable CTRL           17
    variable MSG_REFERENCE  9
    variable PROTOCOL_ID    0
    variable CODE_SCHEME    0
    variable VALIDITY_TIME  255

    variable CDS_7_BIT   0
    variable CDS_8_BIT   4
    variable CDS_UNICODE 8

    array set sms_length [list $CDS_7_BIT 160 $CDS_8_BIT 140 $CDS_UNICODE 70]
    array set code_cheme [list English $CDS_7_BIT Russian $CDS_8_BIT Unicode $CDS_UNICODE]
    array set lang_number [list $CDS_7_BIT 0 $CDS_8_BIT 1 $CDS_UNICODE 2]
}

proc smslib::sms_maxlength {} {
    variable CODE_SCHEME
    variable sms_length
    return $sms_length($CODE_SCHEME)
}

proc smslib::str2lst {lst} {
    set res {}
    foreach {H L} [split $lst {}] {lappend res $H$L}
    return $res
}
proc smslib::change_H2L {str} {
    return [string index $str 1][string index $str 0]
}
proc smslib::hexchar2bit {hex} {
    return [string map {0 0000 1 0001 2 0010 3 0011 4 0100 5 0101 6 0110 7 0111\
	                8 1000 9 1001 A 1010 B 1011 C 1100 D 1101 E 1110 F 1111}\
		[string map {a A b B c C d D e E f F} $hex]]
}
proc smslib::bitchar2hex {bit} {
    return [string map {0000 0 0001 1 0010 2 0011 3 0100 4 0101 5 0110 6 0111 7\
	                1000 8 1001 9 1010 A 1011 B 1100 C 1101 D 1110 E 1111 F} $bit]
}
proc smslib::hex2dec {hex} {
    return [scan $hex "%x"]
}
proc smslib::hex2bit {hex} {
    return [hexchar2bit [string index $hex 0]][hexchar2bit [string index $hex 1]]
}
proc smslib::bit2hex {bit} {
    foreach {b7 b6 b5 b4 b3 b2 b1 b0} [split $bit {}] {break}
    return [bitchar2hex $b7$b6$b5$b4][bitchar2hex $b3$b2$b1$b0]
}


# Convert 7bit GSM compresed message to string
proc smslib::pdumsg2str {sms_data} {
    set bit_str {}
    set res {}
    set counter 7
    set bit_char {}
    set result_str {}
    set sms_data [str2lst $sms_data]

    foreach {char} $sms_data {set bit_str [linsert $bit_str 0 $char]}
    foreach {char} $bit_str {append res [hex2bit $char]}

    for {set i [expr [string length $res] -1]} {$i>=0} {incr i -1} {
	incr counter -1
	append bit_char [string index $res $i]
	if {$counter <= 0} {
	    set char 0
	    for {set c [expr [string length $bit_char] -1]} {$c>=0} {incr c -1} {
		set char [expr $char + [expr [string index $bit_char $c] << $c]]
	    }
	    append result_str [format "%c" $char]
	    set counter 7
	    set bit_char {}
	}
    }
    return $result_str
}
# Convert from string to 7bit GSM compresed
proc smslib::str2pdumsg {sms_data} {
    set bit_str {}
    set res {}

    foreach char [split $sms_data {}] {set bit_str [linsert $bit_str 0 [string replace [hex2bit [format "%02X" [scan $char "%c"]]] 0 0]]}
    set bit_str [split [join $bit_str {}] {}]
    set bit_str [split [join [linsert $bit_str 0 [string repeat 0 [expr 8-[llength $bit_str]%8]]] {}] {}]
    foreach {b7 b6 b5 b4 b3 b2 b1 b0} $bit_str {lappend res $b7$b6$b5$b4$b3$b2$b1$b0}
    set bit_str {}
    foreach oct $res {set bit_str [linsert $bit_str 0 [bit2hex $oct]]}
    return [join $bit_str {}]
}

proc smslib::pdu2phone {pdu_number} {
    set number {}
    foreach {data} [str2lst $pdu_number] {append number [change_H2L $data]}
    set len [expr [string length $number]-1]
    if {![string is digit [string index $number $len]]} {set number [string replace $number $len $len]}
    return $number
}
proc smslib::phone2pdu {number} {
    set pdu {}
    set len [expr [string length $number]]
    if {[expr [expr $len/2]*2] != $len} {append number F}
    foreach {data} [str2lst $number] {append pdu [change_H2L $data]}
    return $pdu
}
proc smslib::convert_date {timesht} {
    set res {}
    foreach {data} [str2lst $timesht] {lappend res [change_H2L $data]}
    return "20[lindex $res 0]/[lindex $res 1]/[lindex $res 2] [lindex $res 3]:[lindex $res 4]:[lindex $res 5] +[lindex $res 6]"
}

proc smslib::decode_sms {sms} {
    variable CDS_7_BIT
    variable CDS_8_BIT
    variable CDS_UNICODE

    set sms [str2lst $sms]
    set res {}
    lappend res [hex2dec [lindex $sms 0]]
    lappend res [hex2dec [lindex $sms 1]]
    set phone {}; for {set i 2} {$i<8} {incr i} {append phone [lindex $sms $i]}
    lappend res [pdu2phone $phone]
    lappend res [hex2dec [lindex $sms 8]]

    set addr_len [hex2dec [lindex $sms 9]]
    lappend res $addr_len
    lappend res [hex2dec [lindex $sms 10]]

    set nextc [expr 11 + [expr $addr_len/2]]
    if {[expr [expr $addr_len/2]*2] != $addr_len} {incr nextc}
    set phone {};
    for {set i 11} {$i<$nextc} {incr i} {append phone [lindex $sms $i]}
    lappend res [pdu2phone $phone]

    lappend res [hex2dec [lindex $sms [expr $nextc+0]]]

    set msg_type [hex2dec [lindex $sms [expr $nextc+1]]]
    lappend res $msg_type

    set timesht {};
    for {set i [expr $nextc+2]} {$i<[expr $nextc+9]} {incr i} {append timesht [lindex $sms $i]}
    lappend res [convert_date $timesht]

    set msg_len [hex2dec [lindex $sms [expr $nextc+9]]]
    lappend res $msg_len
    set msg {}; for {set i [expr $nextc+10]} {$i<[expr $nextc+10+$msg_len]} {incr i} {append msg [lindex $sms $i]}

    if {$msg_type == $CDS_7_BIT} {set msg [pdumsg2str $msg]
    } elseif {$msg_type == $CDS_8_BIT} {set msg [plain2msg $msg]
    } elseif {$msg_type == $CDS_UNICODE} {set msg [unicode2msg $msg]}

    return [lappend res $msg]
}

proc smslib::dec2hex {hex} {
    return [format "%02X" $hex]
}

proc smslib::msg2unicode {msg} {
    set res {}
    foreach char [split $msg {}] {
        binary scan [encoding convertto unicode $char] H2H2 L H
        append res "$H$L"
    }
    return $res
}
proc smslib::unicode2msg {utf} {
    set res {}
    foreach {H1 H0 L1 L0} [split $utf {}] {
        append res [encoding convertfrom unicode [binary format H4 $L1$L0$H1$H0]]
    }
    return $res
}
proc smslib::msg2plain {msg} {
    binary scan [encoding convertto cp855 $msg] H* res
    return $res
}
proc smslib::plain2msg {msg} {
    return [encoding convertfrom cp855 [binary format H* $msg]]
}

proc smslib::encode_sms {sms} {
    variable CODE_SCHEME
    variable CDS_7_BIT
    variable CDS_8_BIT

    set res {}
    set msg [lindex $sms 12]
    set msg_len [string length $msg]

    if {[lindex $sms 9] == $CDS_7_BIT} {
	set msg [str2pdumsg $msg]
    } elseif {[lindex $sms 9] == $CDS_8_BIT} {
	set msg [msg2plain $msg]
    } else {
	set msg_len [expr [string length $msg]*2]
	set msg [msg2unicode [lindex $sms 12]]
    }
    for {set i 0} {$i<=1} {incr i} {append res [dec2hex [lindex $sms $i]]}
    append res [phone2pdu [lindex $sms 2]]
    for {set i 3} {$i<=6} {incr i} {append res [dec2hex [lindex $sms $i]]}
    append res [phone2pdu [lindex $sms 7]]
    for {set i 8} {$i<=10} {incr i} {append res [dec2hex [lindex $sms $i]]}
    append res [dec2hex $msg_len]$msg
    return $res
}


proc smslib::show_msg {smsdata} {
    puts "Oper addr len:   [lindex $smsdata 0]"
    puts "Oper addr type:  [lindex $smsdata 1]"
    puts "Oper phone num:  [lindex $smsdata 2]"
    puts "CTRL:            [lindex $smsdata 3]"
    puts "Msg reference:   [lindex $smsdata 4]"
    puts "User addr len:   [lindex $smsdata 5]"
    puts "User addr type:  [lindex $smsdata 6]"
    puts "User phone num:  [lindex $smsdata 7]"
    puts "Protocol ID:     [lindex $smsdata 8]"
    puts "Code scheme:     [lindex $smsdata 9]"
    puts "Validity preiod: [lindex $smsdata 10]"
    puts "Message length:  [lindex $smsdata 11]"
    puts "Message:         '[lindex $smsdata 12]'"
    puts "--------------------------------------------------------------------"
}

proc smslib::set_oper_number {number type} {
    variable OPER_ADDR_TYPE $type
    variable OPER_NUMBER $number
}

proc smslib::set_language {lang} {
    variable CODE_SCHEME $lang
}

proc smslib::get_addr_type {phone_number} {
    set type {}
    if {[regexp {^\+|^\(\+|^\(0|^0} $phone_number]} {set type 145} else {set type 129}
    return $type
}

proc smslib::correct_number {phone_number} {
    regsub -all {\+|^0|-|\(|\)} $phone_number {} phone_number
    return $phone_number
}

proc smslib::send_sms {user_num msg} {
    variable OPER_ADDR_LEN
    variable OPER_ADDR_TYPE
    variable OPER_NUMBER
    variable CTRL
    variable MSG_REFERENCE
    variable PROTOCOL_ID
    variable CODE_SCHEME
    variable VALIDITY_TIME

    if {![string length $OPER_ADDR_TYPE]} {return -1}
    if {![string length $OPER_NUMBER]}    {return -2}
    if {![string length $user_num]}       {return -3}

    set data [list $OPER_ADDR_LEN $OPER_ADDR_TYPE [correct_number $OPER_NUMBER] \
		  $CTRL $MSG_REFERENCE \
		  [string length [correct_number $user_num]] [get_addr_type $user_num] [correct_number $user_num] \
		  $PROTOCOL_ID $CODE_SCHEME $VALIDITY_TIME \
		  0 $msg]
    set msg [encode_sms $data]
    set len [expr [string length $msg]/2 - [expr 4+[string length $OPER_NUMBER]]/2]
    return [list $msg $len]
}
