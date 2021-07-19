#############################################################################
#
# (C) 2021 Cadence Design Systems, Inc. All rights reserved worldwide.
#
# This sample script is not supported by Cadence Design Systems, Inc.
# It is provided freely for demonstration purposes only.
# SEE THE WARRANTY DISCLAIMER AT THE BOTTOM OF THIS FILE.
#
#############################################################################

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

  pack [label .bottom.logo -image [cadenceLogo] -bd 0 -relief flat] \
      -side left -padx 5

  bind . <KeyPress-Escape> { .bottom.cancel invoke }
  bind . <Control-KeyPress-Return> { .bottom.ok invoke }

  ::tk::PlaceWindow . widget
}

proc cadenceLogo {} {
  set logoData "
R0lGODlhgAAYAPQfAI6MjDEtLlFOT8jHx7e2tv39/RYSE/Pz8+Tj46qoqHl3d+vq62ZjY/n4+NT
T0+gXJ/BhbN3d3fzk5vrJzR4aG3Fubz88PVxZWp2cnIOBgiIeH769vtjX2MLBwSMfIP///yH5BA
EAAB8AIf8LeG1wIGRhdGF4bXD/P3hwYWNrZXQgYmVnaW49Iu+7vyIgaWQ9Ilc1TTBNcENlaGlIe
nJlU3pOVGN6a2M5ZCI/PiA8eDp4bXBtdGEgeG1sbnM6eD0iYWRvYmU6bnM6bWV0YS8iIHg6eG1w
dGs9IkFkb2JlIFhNUCBDb3JlIDUuMC1jMDYxIDY0LjE0MDk0OSwgMjAxMC8xMi8wNy0xMDo1Nzo
wMSAgICAgICAgIj48cmRmOlJERiB4bWxuczpyZGY9Imh0dHA6Ly93d3cudy5vcmcvMTk5OS8wMi
8yMi1yZGYtc3ludGF4LW5zIyI+IDxyZGY6RGVzY3JpcHRpb24gcmY6YWJvdXQ9IiIg/3htbG5zO
nhtcE1NPSJodHRwOi8vbnMuYWRvYmUuY29tL3hhcC8xLjAvbW0vIiB4bWxuczpzdFJlZj0iaHR0
cDovL25zLmFkb2JlLmNvbS94YXAvMS4wL3NUcGUvUmVzb3VyY2VSZWYjIiB4bWxuczp4bXA9Imh
0dHA6Ly9ucy5hZG9iZS5jb20veGFwLzEuMC8iIHhtcE1NOk9yaWdpbmFsRG9jdW1lbnRJRD0idX
VpZDoxMEJEMkEwOThFODExMUREQTBBQzhBN0JCMEIxNUM4NyB4bXBNTTpEb2N1bWVudElEPSJ4b
XAuZGlkOkIxQjg3MzdFOEI4MTFFQjhEMv81ODVDQTZCRURDQzZBIiB4bXBNTTpJbnN0YW5jZUlE
PSJ4bXAuaWQ6QjFCODczNkZFOEI4MTFFQjhEMjU4NUNBNkJFRENDNkEiIHhtcDpDcmVhdG9yVG9
vbD0iQWRvYmUgSWxsdXN0cmF0b3IgQ0MgMjMuMSAoTWFjaW50b3NoKSI+IDx4bXBNTTpEZXJpZW
RGcm9tIHN0UmVmOmluc3RhbmNlSUQ9InhtcC5paWQ6MGE1NjBhMzgtOTJiMi00MjdmLWE4ZmQtM
jQ0NjMzNmNjMWI0IiBzdFJlZjpkb2N1bWVudElEPSJ4bXAuZGlkOjBhNTYwYTM4LTkyYjItNDL/
N2YtYThkLTI0NDYzMzZjYzFiNCIvPiA8L3JkZjpEZXNjcmlwdGlvbj4gPC9yZGY6UkRGPiA8L3g
6eG1wbWV0YT4gPD94cGFja2V0IGVuZD0iciI/PgH//v38+/r5+Pf29fTz8vHw7+7t7Ovp6Ofm5e
Tj4uHg397d3Nva2djX1tXU09LR0M/OzczLysnIx8bFxMPCwcC/vr28u7q5uLe2tbSzsrGwr66tr
KuqqainpqWko6KhoJ+enZybmpmYl5aVlJOSkZCPjo2Mi4qJiIeGhYSDgoGAf359fHt6eXh3dnV0
c3JxcG9ubWxramloZ2ZlZGNiYWBfXl1cW1pZWFdWVlVUU1JRUE9OTUxLSklIR0ZFRENCQUA/Pj0
8Ozo5ODc2NTQzMjEwLy4tLCsqKSgnJiUkIyIhIB8eHRwbGhkYFxYVFBMSERAPDg0MCwoJCAcGBQ
QDAgEAACwAAAAAgAAYAAAF/uAnjmQpTk+qqpLpvnAsz3RdFgOQHPa5/q1a4UAs9I7IZCmCISQwx
wlkSqUGaRsDxbBQer+zhKPSIYCVWQ33zG4PMINc+5j1rOf4ZCHRwSDyNXV3gIQ0BYcmBQ0NRjBD
CwuMhgcIPB0Gdl0xigcNMoegoT2KkpsNB40yDQkWGhoUES57Fga1FAyajhm1Bk2Ygy4RF1seCjw
vAwYBy8wBxjOzHq8OMA4CWwEAqS4LAVoUWwMul7wUah7HsheYrxQBHpkwWeAGagGeLg717eDE6S
4HaPUzYMYFBi211FzYRuJAAAp2AggwIM5ElgwJElyzowAGAUwQL7iCB4wEgnoU/hRgIJnhxUlpA
SxY8ADRQMsXDSxAdHetYIlkNDMAqJngxS47GESZ6DSiwDUNHvDd0KkhQJcIEOMlGkbhJlAK/0a8
NLDhUDdX914A+AWAkaJEOg0U/ZCgXgCGHxbAS4lXxketJcbO/aCgZi4SC34dK9CKoouxFT8cBNz
Q3K2+I/RVxXfAnIE/JTDUBC1k1S/SJATl+ltSxEcKAlJV2ALFBOTMp8f9ihVjLYUKTa8Z6GBCAF
rMN8Y8zPrZYL2oIy5RHrHr1qlOsw0AePwrsj47HFysrYpcBFcF1w8Mk2ti7wUaDRgg1EISNXVwF
lKpdsEAIj9zNAFnW3e4gecCV7Ft/qKTNP0A2Et7AUIj3ysARLDBaC7MRkF+I+x3wzA08SLiTYER
KMJ3BoR3wzUUvLdJAFBtIWIttZEQIwMzfEXNB2PZJ0J1HIrgIQkFILjBkUgSwFuJdnj3i4pEIlg
eY+Bc0AGSRxLg4zsblkcYODiK0KNzUEk1JAkaCkjDbSc+maE5d20i3HY0zDbdh1vQyWNuJkjXnJ
C/HDbCQeTVwOYHKEJJwmR/wlBYi16KMMBOHTnClZpjmpAYUh0GGoyJMxya6KcBlieIj7IsqB0ji
5iwyyu8ZboigKCd2RRVAUTQyBAugToqXDVhwKpUIxzgyoaacILMc5jQEtkIHLCjwQUMkxhnx5I/
seMBta3cKSk7BghQAQMeqMmkY20amA+zHtDiEwl10dRiBcPoacJr0qjx7Ai+yTjQvk31aws92JZ
Q1070mGsSQsS1uYWiJeDrCkGy+CZvnjFEUME7VaFaQAcXCCDyyBYA3NQGIY8ssgU7vqAxjB4EwA
DEIyxggQAsjxDBzRagKtbGaBXclAMMvNNuBaiGAAA7"

  return [image create photo -format GIF -data $logoData]
}

makeWindow
tkwait window .

#############################################################################
#
# This file is licensed under the Cadence Public License Version 1.0 (the
# "License"), a copy of which is found in the included file named "LICENSE",
# and is distributed "AS IS." TO THE MAXIMUM EXTENT PERMITTED BY APPLICABLE
# LAW, CADENCE DISCLAIMS ALL WARRANTIES AND IN NO EVENT SHALL BE LIABLE TO
# ANY PARTY FOR ANY DAMAGES ARISING OUT OF OR RELATING TO USE OF THIS FILE.
# Please see the License for the full text of applicable terms.
#
#############################################################################
