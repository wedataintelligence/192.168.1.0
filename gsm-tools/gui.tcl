# -*- tcl -*-
# $Id: gui.tcl,v 1.6 2002/10/17 17:49:14 grigory Exp $

package require Tk
package require BWidget

#############################################################
# GUI
#############################################################

namespace eval GUI {
    variable top .
}

#############################################################
# Send simple AT command
#############################################################
proc GUI::send_command {} {
    set top ".send_command_window"
    if {[catch {toplevel $top}]} return
    wm title $top "Send command"
    label $top.lb -text "Command"
    entry $top.entry
    set command "puts \[phonelib::send_data \[$top.entry get\]\]; destroy $top"
    button $top.add -text "Add" -command $command
    bind $top <Return> $command
    bind $top <Escape> "destroy $top"
    pack $top.lb $top.entry -side top -expand yes -fill x
    pack $top.add -side top
}


#############################################################
# Work with melodies
#############################################################
proc GUI::edit_mel {top melodies} {
    $top.text delete 1.0 end
    set melody [lindex $melodies [$top.f.combo getvalue]]
    $top.text insert end [lindex $melody 1]
}
proc GUI::play_mel {top melodies} {
    regsub {\n} [$top.text get 1.0 end] {} melody_new
    regsub {\n} [lindex [lindex $melodies [$top.f.combo getvalue]] 1] {} melody_old
    if {![string equal $melody_new $melody_old]} {
	MessageDlg .z -type ok -message "Melody can't write to phone\nPlease write it first."
    } else {
	phonelib::play_melody [expr [$top.f.combo getvalue] + 1]
    }
}
proc GUI::write_mel {top} {
    phonelib::write_melody [expr [$top.f.combo getvalue] + 1] [$top.text get 1.0 end]
}

proc GUI::melody_editor {mel_reader} {
    set top .melody_editor_window
    if {[catch {toplevel $top}]} return
    wm title $top "Melody editor"

    pack [label $top.label -text "Reading melodies..."]
    set melodies [$mel_reader]
    pack unpack $top.label

    set command_edit_mel  "GUI::edit_mel $top \"$melodies\""
    set command_play_mel  "GUI::play_mel $top \"$melodies\""
    set command_write_mel "GUI::write_mel $top"

    text $top.text -height 5 -width 40
    pack [frame $top.f -borderwidth 1 -relief raised] -fill both -pady 2
    label $top.f.combo_label -text "Select melody:"
    ComboBox $top.f.combo -values $melodies -modifycmd $command_edit_mel
    $top.f.combo setvalue first; eval $command_edit_mel

    button $top.play  -text "Play on phone"  -command $command_play_mel
    button $top.write -text "Write to phone" -command $command_write_mel
    button $top.exit  -text "Close"          -command "destroy $top"

    bind $top <Escape> "destroy $top"

    pack $top.f.combo_label -side left
    pack  $top.f.combo $top.text -expand yes -side left -fill x
    pack $top.play $top.write $top.exit -side top
}


############################################################
# Work with SMS
############################################################
proc GUI::send_sms {top} {
    if {[set phone [$top.f.phone_number get]] == {}} {
	tk_messageBox -message "Can't enter phone number or number incorect!" -icon error -type ok -parent $top
	return
    } else {puts "Send SMS to '$phone'"}
    smslib::set_language $::language
    set max_len [smslib::sms_maxlength]
    set text [$top.text get 1.0 "end -1 chars"]
    if {$text=={}} {tk_messageBox -message "Can't enter message!" -icon error -type ok -parent $top; return }
    if {[string length $text] > $max_len} {
	set text [string replace $text $max_len end {}]
	$top.text delete 1.0 end
	$top.text insert 1.0 $text
	return
    }

    set wn $top.sms_sending
    if {[catch {toplevel $wn}]} return
    wm title $wn {}
    wm geometry $wn =[winfo geometry $top]
    pack [label $wn.label -font {Courier 16} -text "Sending sms..."]

    set msg [smslib::send_sms $phone $text]
puts $msg
    set msg_sended 0
    while {!$msg_sended} {
	puts $phonelib::f_phone "at+cmgs=[lindex $msg 1]\n"
	after 500
	if {[regexp {>} [read $phonelib::f_phone]]} {
	    set res [phonelib::send_data "[lindex $msg 0]\x1A"]
#	    set res "OK"
	    if {![set msg_sended [regexp -all {OK} $res]]} {
		if {[tk_messageBox -message "Err:\n$res\nrepeat?" -icon error -type yesno]=="no"} {set msg_sended 1}
	    } else {set msg_sended 1}
	} else {puts "Phone not ready, +cmgs error"}
    }
    $top.text delete 1.0 end
    set ::DEF_NUMBER $phone
    destroy $top
}

proc GUI::sms_sender {{number {}} {rep_sms {}} {sms_type {}}} {
    set top .sms_sender
    if {[catch {toplevel $top}]} return

    wm title $top "Send SMS via oper: $smslib::OPER_NUMBER"
    wm resizable $top 0 0
    text $top.text -height 7 -width 40 -wrap word

    pack [frame $top.lang -borderwidth 1 -relief raised] -fill both -pady 2
    foreach lang [lsort [array names smslib::code_cheme]] {
	set radio_name [string tolower $lang]
	radiobutton $top.lang.$radio_name -text $lang -variable ::language -value $smslib::code_cheme($lang)
	pack $top.lang.$radio_name -side left
    }
    $top.lang.[string tolower [lindex [lsort [array names smslib::code_cheme]] $smslib::lang_number($::language)]] select

    pack [frame $top.f -borderwidth 1 -relief raised] -fill both -pady 2
    label $top.f.label -text "Destination:"
    entry $top.f.phone_number -textvariable phone::SELECTED_RECORD(number)
    ComboBox $top.entry -values [phone::names_list] -font {Courier 14} -editable 1 -textvariable phone::SELECTED_RECORD(name)
    bind $top.f.phone_number <Return> "set phone::SELECTED_RECORD(number) \[phone::get_number \$phone::SELECTED_RECORD(name)\]"
    bind $top.entry.e <Return> "set phone::SELECTED_RECORD(name) \[phone::get_name \$phone::SELECTED_RECORD(number)\]; $top.entry.e selection range insert end"
    bind $top.entry.e <Tab> "focus $top.text; break"

    if {$rep_sms != {}} {$top.text insert 1.0 $rep_sms}
    if {$sms_type != {}} {set ::language $sms_type}

    if {$number != {}} {$top.f.phone_number insert 0 $number}

    button $top.send -text "Send" -command "GUI::send_sms $top"
    button $top.clear -text "Clear" -command "$top.text delete 1.0 end"
    button $top.exit -text "Close" -command "destroy $top"

    bind $top <Escape> "destroy $top"
    bind $top <Control-Return> "GUI::send_sms $top; break"

    pack $top.f.label $top.f.phone_number -expand yes -side left -fill x
    pack $top.entry -side top -fill x

    pack $top.text -side left -fill x
    pack $top.send $top.clear $top.exit -side top

    # binding default cursor position and tab order
    focus $top.entry
}

proc GUI::gets_sms {top} {
    $top.text delete 1.0 end
    $top.text tag configure font1 -font {Courier 14} -foreground white -background #606060
    $top.text tag configure font2 -font {Courier 12} -foreground red -background lightblue
    $top.text tag configure font3 -background lightblue
    set messages [phonelib::read_all_sms]
    foreach sms $messages {
	foreach line $sms {puts "$line\n"}
	set sms [lindex $sms 1]
	$top.text insert end "From: " font3
	$top.text insert end "[lindex $sms 6] " font2
	$top.text insert end "Date: [lindex $sms 9] SMS number: [lindex $sms 2]\n" font3
	$top.text insert end "'[lindex $sms 11]'\n\n" font1
    }
}

proc GUI::sms_reader {} {
    set top .sms_reader
    if {[catch {toplevel $top}]} return
    pack [frame $top.f -borderwidth 1 -relief raised] -fill both -pady 2

    wm title $top "Received SMS"
    frame $top.t -borderwidth 1 -relief raised
    text $top.t.text -yscrollcommand "$top.t.scroll set" -wrap word -height 15 -width 100
    scrollbar $top.t.scroll -command "$top.t.text yview"

    pack [label $top.label -text "Reading sms..."]
    gets_sms $top.t
    pack unpack $top.label

    pack $top.t -side left -pady 2
    pack $top.t.scroll -side right -fill y
    pack $top.t.text -side left -fill x

    button $top.read -text "Read" -command "GUI::gets_sms $top.t"
    button $top.exit -text "Close" -command "destroy $top"

    bind $top <Escape> "destroy $top"
    bind $top.t.text <Control-Return> "GUI::send_sms $top; break"

    pack $top.read $top.exit -side top
}

proc GUI::show_recived_msg {sms} {
    set top .res_msg[lindex $sms 6][lindex [split [lindex $sms 9] { }] 1]
    if {[catch {toplevel $top}]} return
    wm title $top "Recieved msg: [lindex $sms 6]"
 
    text $top.text -height 15 -width 40 -wrap word
    bind $top <Escape> "destroy $top"
    pack $top.text

    set tag_new newsms
    set tag_rep repsms
    $top.text tag configure font1 -foreground red -background yellow
    $top.text tag configure font2 -font {Courier 14} -foreground white -background #606060
    $top.text insert end "From:       " font1
    $top.text insert end "[lindex $sms 6]" $tag_new
    $top.text insert end "\nSMS center: [lindex $sms 2]\n" font1
    $top.text insert end "Date:       [lindex $sms 9]\n\n" font1
    $top.text insert end "[lindex $sms 11]" $tag_rep

    $top.text tag configure $tag_new -font {Courier 14} -foreground black -background yellow
    $top.text tag configure $tag_rep -font {Courier 14}

    foreach tag [list $tag_new $tag_rep] {
	$top.text tag bind $tag <Any-Enter> \
	    "$top.text tag configure $tag -background cyan -relief raised -borderwidth 1"
    }
    $top.text tag bind $tag_new <Any-Leave> "$top.text tag configure $tag_new -relief flat -background yellow"
    $top.text tag bind $tag_rep <Any-Leave> "$top.text tag configure $tag_rep -relief flat -background {}"
    $top.text tag bind $tag_new <1> "GUI::sms_sender [lindex $sms 6]; destroy $top; break"
    $top.text tag bind $tag_rep <1> "GUI::sms_sender [lindex $sms 6] \{[lindex $sms 11]\} [lindex $sms 8]; destroy $top; break"
}


############################################################
# Work with Incoming and Outgoing calls
############################################################
proc GUI::show_incoming_call {{number {}} {type {}}} {
    set top .incoming_call$number
    if {[catch {toplevel $top}]} return
    wm title $top "Incoming Call..."

    pack [frame $top.f -borderwidth 1 -relief raised] -side top -pady 2
    label $top.f.label -text "Number:"
    entry $top.f.entry -font {Courier 14}
    $top.f.entry insert 0 $number
    pack $top.f.label $top.f.entry -side left
 
    set call_command "phonelib::voice_call \[$top.f.entry get\]"
    pack [frame $top.t -borderwidth 1 -relief raised] -side bottom -pady 2 -fill x
    button $top.t.answer -text "Answer" -underline 0 -command {phonelib::voice_answer}
    button $top.t.busy   -text "Busy"   -underline 0 -command {phonelib::voice_busy}
    button $top.t.call   -text "Call"   -underline 0 -command $call_command
    button $top.t.close  -text "Exit"   -underline 1 -command "destroy $top"
    pack $top.t.answer $top.t.busy $top.t.call $top.t.close -side left -fill x

    event add <<Exit>> <Alt-x>
    event add <<Exit>> <Escape>
    bind $top <<Exit>> "destroy $top; break"
    bind $top <Alt-a> phonelib::voice_answer
    bind $top <Alt-b> phonelib::voice_busy
    bind $top <Alt-c> $call_command
} 


####################################################################################
set ::received_sms_ex [list [smslib::decode_sms 0791732569000900040C917325697744460008209092329431008A0052006500630065006900760065006400200053004D0053002000650078002E002C0020007000720065007300730020006F006E0020007400650078007400200066006F00720020007200650070006C00790020006F00720020006F006E0020006E0075006D00620065007200200066006F00720020007700720069007400650020006E00650077002E]]
# 0791732569000900040C9173256935144200082090715152020010041F0440043E043204350440043A0430

proc GUI::update {} {
    wm title . "Phone: $phonelib::PHONE_MODEL"
}

proc GUI::init {} {
    variable top
    set melody_editor_command {GUI::melody_editor phonelib::melodies}
    set call_command "GUI::show_incoming_call 411 129"

    bind $top <Alt-x> "destroy $top"
    bind $top <Alt-n> GUI::send_command
    bind $top <Alt-m> $melody_editor_command
    bind $top <Alt-s> GUI::sms_sender
    bind $top <Alt-r> GUI::sms_reader
    bind $top <Alt-c> $call_command

    button .send_command  -text "Send command"  -underline 2 -command {GUI::send_command}
    button .melody_editor -text "Melody editor" -underline 0 -command $melody_editor_command
    button .send_sms      -text "Send SMS"      -underline 0 -command {GUI::sms_sender}
    button .read_sms      -text "Read SMS"      -underline 0 -command {GUI::sms_reader}
    button .call          -text "Call"          -underline 0 -command $call_command
    button .exit          -text "Exit"          -underline 1 -command {phonelib::close_port; exit}
    button .example       -text "Receive SMS example" -command "GUI::show_recived_msg $::received_sms_ex"

    pack .send_command .melody_editor .send_sms .read_sms .call .example .exit -fill x

    button .save_book -text "Save ph_book" -command "phone::write_book_to_file \[phonelib::read_all_numbers\]"
    pack .save_book
}

GUI::init
