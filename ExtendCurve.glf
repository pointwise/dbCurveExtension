#
# Copyright 2009 (c) Pointwise, Inc.
# All rights reserved.
#
# This sample Pointwise script is not supported by Pointwise, Inc.
# It is provided freely for demonstration purposes only.
# SEE THE WARRANTY DISCLAIMER AT THE BOTTOM OF THIS FILE.
#

package require PWI_Glyph 2

pw::Script loadTk


#######################################################
#
#            ----------------------------
#         p2/                            \p3
#          /                              \
#        p1                                p4
#
#  Extend both ends of a DB curve to a given length.
#
#          U is within the range [0.0,1.0]
#
#######################################################

set extensionLength 10.0
set U 0.001

set extended 0

############################################################################
# AdjustAccuracy: Decrease U for better accuracy.
############################################################################
proc AdjustAccuracy {} {
  global U selected
  set U [expr $U/10.0]
}

proc ExtendCurve {} {
  global selected extensionLength U extended

  if { ! [info exists selected] } {
    return
  }

  UndoExtend 0

  # Calculate the unit vector of the slopes of the two ends.
  set p1 [$selected getXYZ -parameter 0.0]
  set p2 [$selected getXYZ -parameter $U]
  set normal12 [pwu::Vector3 normalize [pwu::Vector3 subtract $p1 $p2]]
  set normal12 [pwu::Vector3 scale $normal12 $extensionLength]
  set x1 [pwu::Vector3 add $p1 $normal12]

  set p3 [$selected getXYZ -parameter [expr 1.0-$U] ]
  set p4 [$selected getXYZ -parameter 1.0 ]
  set normal34 [pwu::Vector3 normalize [pwu::Vector3 subtract $p4 $p3]]
  set normal34 [pwu::Vector3 scale $normal34 $extensionLength]
  set x4 [pwu::Vector3 add $p4 $normal34]


  # Create two DB extensions.
  set seg1 [pw::SegmentSpline create]
  $seg1 addPoint $x1
  $seg1 addPoint $p1
  $selected insertSegment 1 $seg1

  set segN [pw::SegmentSpline create]
  $segN addPoint $p4
  $segN addPoint $x4
  $selected addSegment $segN

  set extended 1

  pw::Display update

  .bottom.accu configure -state active
  .bottom.undo configure -state active
}

############################################################################
# UndoExtend: Remove curve extension segments
############################################################################
proc UndoExtend { {update 1} } {
  global selected extended U

  if { [info exists selected] && $extended } {
    $selected removeSegment 1
    $selected removeSegment [$selected getSegmentCount]
    set extended 0
    if $update {
      pw::Display update
    }
  }
  .bottom.accu configure -state disabled
  .bottom.undo configure -state disabled
}

############################################################################
# SelectCurve: pick curve/con to extend
############################################################################
proc SelectCurve { } {
  global selected extended crvFontValid crvFontInvalid

  wm withdraw .
  .bottom.accu configure -state disabled

  set dbMask [pw::Display createSelectionMask -requireDatabase {Curves} \
    -requireConnector {Free}]
  pw::Display selectEntities -single -selectionmask $dbMask -description \
    "Select the database curve or free connector to extend" results

  if [info exists selected] {
    unset selected
  }

  if { [info exists results(Databases)] && \
      [llength $results(Databases)] == 1 } {
    set selected $results(Databases)
  } elseif { [info exists results(Connectors)] && \
      [llength $results(Connectors)] == 1 } {
    set selected $results(Connectors)
  } else {
    .bottom.ok configure -state disabled
    .buttons.curveName configure -text "(No curve)" -font $crvFontInvalid
  }

  if [info exists selected] {
    set U 0.001
    .bottom.ok configure -state active
    .buttons.curveName configure -text [$selected getName] -font $crvFontValid
  }

  set extended 0
  wm deiconify .
}

############################################################################
# makeInputField: create a Tk text field
############################################################################
proc makeInputField {parent name title variable {width 7} {valid ""}} {
  frame $parent.$name
  label .lbl$name -text $title
  entry .ent$name -textvariable $variable -width $width
  if { [string compare $valid ""]!=0 } {
    .ent$name configure -validate all
    .ent$name configure -validatecommand $valid
  }
  pack ".lbl$name" -side left -padx 3 -pady 1 -in $parent.$name
  pack ".ent$name" -side right -padx 3 -pady 1 -in $parent.$name
  return $parent.$name
}

############################################################################
# makeWindow: build the Tk interface
############################################################################
proc makeWindow { } {
  global extensionLength crvFontValid crvFontInvalid

  wm title . "Extend a DB Curve"

  pack [frame .top] -fill x -padx 1 -pady 2
  pack [label .top.lbl1 -text "Extend DB curve" -wraplength 330 -justify center]
  pack [frame .top.hr -height 2 -relief sunken -borderwidth 1] \
    -side top -fill x

  set font [font actual [.top.lbl1 cget -font] -family]
  set crvFontValid [font create -family $font -weight bold]
  set crvFontInvalid [font create -family $font -slant italic]
  
  .top.lbl1 configure -font [font create -family $font -weight bold]

  pack [frame .buttons -width 300 -height 400] -padx 2 -pady 5

  pack [button .buttons.enterSelect -text "Select Curve/Connector" \
    -command { SelectCurve } -width 20] -side top -pady 4 -padx 2
  pack [label .buttons.curveName -justify center] -side top -pady 4
  .buttons.curveName configure -text "(No curve)" -font $crvFontInvalid

  pack [makeInputField .buttons inp1 "Extension Length" extensionLength 7] \
    -pady 4

  pack [frame .hr -height 2 -relief sunken -borderwidth 1] \
    -side top -fill x
  pack [frame .bottom] -expand true -fill x -pady 5
  pack [button .bottom.cancel -text "Done" -command { exit }] \
    -side right -padx 5
  pack [button .bottom.undo -text "Undo" \
    -command { UndoExtend; set U 0.001; } -state disabled] \
    -side right -padx 5
  pack [button .bottom.accu -text "Adjust" \
    -command { AdjustAccuracy; ExtendCurve } -state disabled] \
    -side right -padx 5
  pack [button .bottom.ok -text "Extend" \
    -command { ExtendCurve } -state disabled] \
    -side right -padx 5

  pack [label .bottom.logo -image [pwLogo] -bd 0 -relief flat] \
      -side left -padx 5

  bind . <KeyPress-Escape> { .bottom.cancel invoke }
  bind . <Control-KeyPress-Return> { .bottom.ok invoke }

  ::tk::PlaceWindow . widget
}

proc pwLogo {} {
  set logoData "
R0lGODlheAAYAIcAAAAAAAICAgUFBQkJCQwMDBERERUVFRkZGRwcHCEhISYmJisrKy0tLTIyMjQ0
NDk5OT09PUFBQUVFRUpKSk1NTVFRUVRUVFpaWlxcXGBgYGVlZWlpaW1tbXFxcXR0dHp6en5+fgBi
qQNkqQVkqQdnrApmpgpnqgpprA5prBFrrRNtrhZvsBhwrxdxsBlxsSJ2syJ3tCR2siZ5tSh6tix8
ti5+uTF+ujCAuDODvjaDvDuGujiFvT6Fuj2HvTyIvkGKvkWJu0yUv2mQrEOKwEWNwkaPxEiNwUqR
xk6Sw06SxU6Uxk+RyVKTxlCUwFKVxVWUwlWWxlKXyFOVzFWWyFaYyFmYx16bwlmZyVicyF2ayFyb
zF2cyV2cz2GaxGSex2GdymGezGOgzGSgyGWgzmihzWmkz22iymyizGmj0Gqk0m2l0HWqz3asznqn
ynuszXKp0XKq1nWp0Xaq1Hes0Xat1Hmt1Xyt0Huw1Xux2IGBgYWFhYqKio6Ojo6Xn5CQkJWVlZiY
mJycnKCgoKCioqKioqSkpKampqmpqaurq62trbGxsbKysrW1tbi4uLq6ur29vYCu0YixzYOw14G0
1oaz14e114K124O03YWz2Ie12oW13Im10o621Ii22oi23Iy32oq52Y252Y+73ZS51Ze81JC625G7
3JG825K83Je72pW93Zq92Zi/35G+4aC90qG+15bA3ZnA3Z7A2pjA4Z/E4qLA2KDF3qTA2qTE3avF
36zG3rLM3aPF4qfJ5KzJ4LPL5LLM5LTO4rbN5bLR6LTR6LXQ6r3T5L3V6cLCwsTExMbGxsvLy8/P
z9HR0dXV1dbW1tjY2Nra2tzc3N7e3sDW5sHV6cTY6MnZ79De7dTg6dTh69Xi7dbj7tni793m7tXj
8Nbk9tjl9N3m9N/p9eHh4eTk5Obm5ujo6Orq6u3t7e7u7uDp8efs8uXs+Ozv8+3z9vDw8PLy8vL0
9/b29vb5+/f6+/j4+Pn6+/r6+vr6/Pn8/fr8/Pv9/vz8/P7+/gAAACH5BAMAAP8ALAAAAAB4ABgA
AAj/AP8JHEiwoMGDCBMqXMiwocOHECNKnEixosWLGDNqZCioo0dC0Q7Sy2btlitisrjpK4io4yF/
yjzKRIZPIDSZOAUVmubxGUF88Aj2K+TxnKKOhfoJdOSxXEF1OXHCi5fnTx5oBgFo3QogwAalAv1V
yyUqFCtVZ2DZceOOIAKtB/pp4Mo1waN/gOjSJXBugFYJBBflIYhsq4F5DLQSmCcwwVZlBZvppQtt
D6M8gUBknQxA879+kXixwtauXbhheFph6dSmnsC3AOLO5TygWV7OAAj8u6A1QEiBEg4PnA2gw7/E
uRn3M7C1WWTcWqHlScahkJ7NkwnE80dqFiVw/Pz5/xMn7MsZLzUsvXoNVy50C7c56y6s1YPNAAAC
CYxXoLdP5IsJtMBWjDwHHTSJ/AENIHsYJMCDD+K31SPymEFLKNeM880xxXxCxhxoUKFJDNv8A5ts
W0EowFYFBFLAizDGmMA//iAnXAdaLaCUIVtFIBCAjP2Do1YNBCnQMwgkqeSSCEjzzyJ/BFJTQfNU
WSU6/Wk1yChjlJKJLcfEgsoaY0ARigxjgKEFJPec6J5WzFQJDwS9xdPQH1sR4k8DWzXijwRbHfKj
YkFO45dWFoCVUTqMMgrNoQD08ckPsaixBRxPKFEDEbEMAYYTSGQRxzpuEueTQBlshc5A6pjj6pQD
wf9DgFYP+MPHVhKQs2Js9gya3EB7cMWBPwL1A8+xyCYLD7EKQSfEF1uMEcsXTiThQhmszBCGC7G0
QAUT1JS61an/pKrVqsBttYxBxDGjzqxd8abVBwMBOZA/xHUmUDQB9OvvvwGYsxBuCNRSxidOwFCH
J5dMgcYJUKjQCwlahDHEL+JqRa65AKD7D6BarVsQM1tpgK9eAjjpa4D3esBVgdFAB4DAzXImiDY5
vCFHESko4cMKSJwAxhgzFLFDHEUYkzEAG6s6EMgAiFzQA4rBIxldExBkr1AcJzBPzNDRnFCKBpTd
gCD/cKKKDFuYQoQVNhhBBSY9TBHCFVW4UMkuSzf/fe7T6h4kyFZ/+BMBXYpoTahB8yiwlSFgdzXA
5JQPIDZCW1FgkDVxgGKCFCywEUQaKNitRA5UXHGFHN30PRDHHkMtNUHzMAcAA/4gwhUCsB63uEF+
bMVB5BVMtFXWBfljBhhgbCFCEyI4EcIRL4ChRgh36LBJPq6j6nS6ISPkslY0wQbAYIr/ahCeWg2f
ufFaIV8QNpeMMAkVlSyRiRNb0DFCFlu4wSlWYaL2mOp13/tY4A7CL63cRQ9aEYBT0seyfsQjHedg
xAG24ofITaBRIGTW2OJ3EH7o4gtfCIETRBAFEYRgC06YAw3CkIqVdK9cCZRdQgCVAKWYwy/FK4i9
3TYQIboE4BmR6wrABBCUmgFAfgXZRxfs4ARPPCEOZJjCHVxABFAA4R3sic2bmIbAv4EvaglJBACu
IxAMAKARBrFXvrhiAX8kEWVNHOETE+IPbzyBCD8oQRZwwIVOyAAXrgkjijRWxo4BLnwIwUcCJvgP
ZShAUfVa3Bz/EpQ70oWJC2mAKDmwEHYAIxhikAQPeOCLdRTEAhGIQKL0IMoGTGMgIBClA9QxkA3U
0hkKgcy9HHEQDcRyAr0ChAWWucwNMIJZ5KilNGvpADtt5JrYzKY2t8nNbnrzm+B8SEAAADs="

  return [image create photo -format GIF -data $logoData]
}

makeWindow
tkwait window .

#
# DISCLAIMER:
# TO THE MAXIMUM EXTENT PERMITTED BY APPLICABLE LAW, POINTWISE DISCLAIMS
# ALL WARRANTIES, EITHER EXPRESS OR IMPLIED, INCLUDING, BUT NOT LIMITED
# TO, IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
# PURPOSE, WITH REGARD TO THIS SCRIPT.  TO THE MAXIMUM EXTENT PERMITTED 
# BY APPLICABLE LAW, IN NO EVENT SHALL POINTWISE BE LIABLE TO ANY PARTY 
# FOR ANY SPECIAL, INCIDENTAL, INDIRECT, OR CONSEQUENTIAL DAMAGES 
# WHATSOEVER (INCLUDING, WITHOUT LIMITATION, DAMAGES FOR LOSS OF 
# BUSINESS INFORMATION, OR ANY OTHER PECUNIARY LOSS) ARISING OUT OF THE 
# USE OF OR INABILITY TO USE THIS SCRIPT EVEN IF POINTWISE HAS BEEN 
# ADVISED OF THE POSSIBILITY OF SUCH DAMAGES AND REGARDLESS OF THE 
# FAULT OR NEGLIGENCE OF POINTWISE.
#

