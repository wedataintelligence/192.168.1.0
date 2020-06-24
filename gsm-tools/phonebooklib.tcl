#!/usr/bin/tclsh
# -*- tcl -*-
# $Id: phonebooklib.tcl,v 1.2 2002/10/17 17:35:51 grigory Exp $

package provide phonebooklib 0.1

namespace eval phone {
    set PhoneBook {}
    set PhoneBookFile {}
    array set SELECTED_RECORD [list number {} name {} type {}]

#    trace add variable SELECTED_RECORD write [namespace current]::sync_by_name
}

proc phone::write_book_to_file {{book {}}} {
    variable PhoneBook
    if {$book != {}} {set PhoneBook $book}
    set f [open $::PhoneBookFile a+]
    foreach record $PhoneBook {puts $f $record}
    close $f
}

proc phone::read_book_from_file {} {
    variable PhoneBook {}
    if {[catch {set f [open $::PhoneBookFile r]}]} { return 1}
    while {![eof $f]} {lappend PhoneBook [gets $f]}
    close $f
    return 0
}

proc phone::names_list {} {
    variable PhoneBook
    set res {}
    foreach line $PhoneBook {
	lappend res "[lindex $line 3]"
    }
    return [lsort $res]
}

proc phone::correct_number {number type} {
    if {$type == 145} { return +$number}
    return $number
}

proc phone::get_number {name} {
    variable PhoneBook
    set res [lsearch -inline -regexp $PhoneBook $name]
    if {$res == {}} {
	regsub {^\+|^0} $name {} phone
	if {[string is digit $phone]} { return $name}
	return {}
    }
    return [correct_number [lindex $res 1] [lindex $res 2]]
}

proc phone::get_name {number} {
    variable PhoneBook
    regsub -all {\+} $number {} number
    set res [lindex [lsearch -inline -regexp $PhoneBook $number] 3]
    if {$res == {}} { return $number}
    return $res
}

proc phone::sync_by_name {{name1 {}} {name2 {}} {op {}}} {
    variable SELECTED_RECORD
    trace remove variable SELECTED_RECORD write [namespace current]::sync_by_name
#    puts "Parms: '$name1' '$name2' '$op'"
    if {$name2 == {name}} {
	set phone::SELECTED_RECORD(number) [phone::get_number $phone::SELECTED_RECORD(name)]
    } elseif {$name2 == {number}} {
	set phone::SELECTED_RECORD(name) [phone::get_name $phone::SELECTED_RECORD(number)]
    }
    trace add variable SELECTED_RECORD write [namespace current]::sync_by_name
}

proc phone::init_phonebook {} {
    sync_by_name
    read_book_from_file
}