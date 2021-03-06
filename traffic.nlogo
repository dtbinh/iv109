;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Variables
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

globals [
  high-priority-color low-priority-color
  center-xcor center-ycor
  lights-horizontal?
  lane-gap
  green-begin
]

patches-own [
  patch-type ; Type of patch, can be "road", "grass", "intersection", "spawn", "light"
  spawn-location ; For spawns, can be points of compass
  priority
  next-patch
  allocated?
  stop?
  light-color
  max-speed ; Maximum allowed speed on a patch
]

turtles-own [
  ticks-alive
  speed
  origin
  preferred-turn
]


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Setup procedures
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to startup
  clear-all
  
  reset-ticks
  
  set center-xcor round(world-width / 2)
  set center-ycor round(world-height / 2)
  
  set lights-horizontal? true
  
  set high-priority-color black
  set low-priority-color 5
  
  make-world
end


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Create worlds
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to make-world

  ; Set defaults for patches
  ask patches [
    set next-patch (list)
    set allocated? false
    set priority 0
  ]

  ; 1. Color all patches white
  ask patches [
    set pcolor white
    set stop? false
  ]
  
  ; 2. Draw intersection
  if ( intersection = "roundabout" ) [
    set lane-gap round(radius / 3)
    draw-roundabout
  ]
  if ( intersection = "roundabout-quick-right" ) [
    set lane-gap round(radius / 3)
    draw-roundabout-quick-right
  ]
  if ( intersection = "traffic-lights" ) [
    set lane-gap traffic-lights-gap
    
    ; Make traffic lights
    ask patch (center-xcor + lane-gap) (center-ycor - lane-gap - 1) [
      set patch-type "light"
      set stop? false
      set light-color green
    ]
    ask patch (center-xcor - lane-gap) (center-ycor + lane-gap + 1) [
      set patch-type "light"
      set stop? false
      set light-color green
    ]
    ask patch (center-xcor + lane-gap + 1) (center-ycor + lane-gap) [
      set patch-type "light"
      set stop? true
      set light-color red
    ]
    ask patch (center-xcor - lane-gap - 1) (center-ycor - lane-gap) [
      set patch-type "light"
      set stop? true
      set light-color red
    ]
    
    ask patches with [ patch-type = "light" ] [
      set pcolor light-color
    ]
    
    switch-lights
  ]
  
  ; 4. Draw roads with spawns
  make-spawn 1 (center-ycor - lane-gap) "west"  
  make-spawn (world-width - 2) (center-ycor + lane-gap)  "east"  
  make-spawn (center-xcor - lane-gap) (world-height - 2) "north"
  make-spawn (center-xcor + lane-gap) 1 "south"
  
  ; 5. Add center reference point
  ask patch center-xcor center-ycor [
    set pcolor 1
  ]
  
end


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Make intersections
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to draw-roundabout
  let tmp 0
  let tmp-delta 0

  ; Draw circle
  let i 0
  create-turtles 1 [
    
    while [ i < 360 ] [
     setxy (center-xcor + round(radius * sin i)) (center-ycor + (radius * cos i))
     ask patch-here [
       set pcolor high-priority-color
       let next-x (center-xcor + round(radius * sin (i - 1)))
       let next-y (center-ycor + round(radius * cos (i - 1)))
       set next-patch ( lput (patch next-x next-y) next-patch )
       set next-patch ( remove-duplicates next-patch )
       set next-patch ( remove (patch pxcor pycor) next-patch )
       set priority 2
       set max-speed roundabout-circle-speed
     ]
     set i (i + 1)
    ]
    
    die
  ]
    
  ; Road from north
  let north-patches patches with [
     pxcor = (center-xcor - lane-gap) and
     ( pycor > (max [pycor] of patches with [ pxcor = (center-ycor - lane-gap) and priority = 2 ]) or
       pycor <= (min [pycor] of patches with [ pxcor = (center-ycor - lane-gap) and priority = 2 ])
     ) and
     pycor > 2
  ]
  draw-road north-patches 0 -1 1 low-priority-color roundabout-road-speed
  
  ; Road from south
  let south-patches patches with [
     pxcor = (center-xcor + lane-gap) and
     ( pycor >= (max [pycor] of patches with [ pxcor = (center-xcor + lane-gap) and priority = 2 ]) or
       pycor < (min [pycor] of patches with [ pxcor = (center-xcor + lane-gap) and priority = 2 ])
     ) and
     pycor < world-height - 2
  ]
  draw-road south-patches 0 1 1 low-priority-color roundabout-road-speed
  
  ; Road from east
  let east-patches patches with [
     pycor = (center-ycor - lane-gap) and
     ( pxcor >= (max [pxcor] of patches with [ pycor = (center-ycor - lane-gap) and priority = 2 ]) or
       pxcor < (min [pxcor] of patches with [ pycor = (center-ycor - lane-gap) and priority = 2 ])
     ) and
     pxcor < world-width - 2
  ]
  draw-road east-patches 1 0 1 low-priority-color roundabout-road-speed
  
  ; Road from west
  let west-patches patches with [
     pycor = (center-ycor + lane-gap) and
     ( pxcor > (max [pxcor] of patches with [ pycor = (center-ycor + lane-gap) and priority = 2 ]) or
       pxcor <= (min [pxcor] of patches with [ pycor = (center-ycor + lane-gap) and priority = 2 ])
     ) and
     pxcor > 2
  ]
  draw-road west-patches -1 0 1 low-priority-color roundabout-road-speed
  
end

to draw-roundabout-quick-right
  draw-roundabout
  
  let i 0
  let previous-patch (patch 0 0)
  let outer-radius (radius + 5)
  
  while [ i > -360 ] [ ; Rotate counter-clock-wise
    set i (i - 1)
    let continue? true
    
    ; Get new patch
    let current-patch (patch (center-xcor + round(outer-radius * sin i)) (center-ycor + (outer-radius * cos i)))
    
    ; Check if patch is really new
    if (current-patch = previous-patch) [ set continue? false ]
    
    ; Check bounds
    if continue? [
      if ( [pxcor] of current-patch > center-xcor - lane-gap ) and ( [pxcor] of current-patch < center-xcor + lane-gap ) [
        set continue? false
      ]
      if ( [pycor] of current-patch > center-ycor - lane-gap ) and ( [pycor] of current-patch < center-ycor + lane-gap ) [
        set continue? false
      ]
    ]
    
    ; Assign new patch
    if continue? [
      ask previous-patch [
         set pcolor low-priority-color
         set priority 1
         set next-patch ( lput (current-patch) next-patch )
         set next-patch ( remove-duplicates next-patch )
         set max-speed roundabout-circle-speed
      ]
      set previous-patch current-patch
    ]
  
  ]
end

to draw-traffic-lights [ priority1 priority2 priority1-color priority2-color ]

  ; Road from north
  let north-patches patches with [
     pxcor = (center-xcor - lane-gap) and
     pycor > 2 and
     patch-type != "spawn"
  ]
  draw-road north-patches 0 -1 priority1 priority1-color traffic-lights-speed
  
  ; Road from south
  let south-patches patches with [
     pxcor = (center-xcor + lane-gap) and
     pycor < world-height - 2 and
     patch-type != "spawn"
  ]
  draw-road south-patches 0 1 priority1 priority1-color traffic-lights-speed
  
  ; Road from east
  let east-patches patches with [
     pycor = (center-ycor - lane-gap) and
     pxcor < world-width - 2 and
     patch-type != "spawn"
  ]
  draw-road east-patches 1 0 priority2 priority2-color traffic-lights-speed
  
  ; Road from west
  let west-patches patches with [
     pycor = (center-ycor + lane-gap) and
     pxcor > 2 and
     patch-type != "spawn"
  ]
  draw-road west-patches -1 0 priority2 priority2-color traffic-lights-speed

end

to draw-road [ fields move-x move-y pr clr road-speed ]
  ask fields [
    set priority pr
    set pcolor clr
    set next-patch (lput (patch-at move-x move-y) next-patch)
    set next-patch (remove-duplicates next-patch)
    set max-speed road-speed
  ]
end

to make-spawn [ loc-x loc-y name ]
  ask patch loc-x loc-y [
    set patch-type "spawn"
    set spawn-location name
    set pcolor 44
  ]
end


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Add cars
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to add-from-north
  ; Cannot make north turn
  car-factory "north" 180 (list (list 1 0) (list -1 0) (list 0 -1))
end

to add-from-south
  ; Cannot make south turn
  car-factory "south" 0 (list (list 1 0) (list -1 0) (list 0 1))
end

to add-from-east
  ; Cannot make east turn
  car-factory "east" 270 (list (list 0 1) (list -1 0) (list 0 -1))
end

to add-from-west
  ; Cannot make west turn
  car-factory "west" 90 (list (list 1 0) (list 0 1) (list 0 -1))
end

to car-factory [ location orientation possible-turns ] 
  
  ask patches with [ spawn-location = location ] [
    sprout 1 [
      set origin location
      set heading orientation
      set size 3.5
      set speed ([max-speed] of patch-here)
      set preferred-turn item (random 3) possible-turns
      ;set preferred-turn item (random 4) (list (list 1 0) (list 0 1) (list -1 0) (list 0 -1))
    ]
  ]
end

to add-cars-on-frequency
  if (random 100 < north-frequency) [ add-from-north ]
  if (random 100 < south-frequency) [ add-from-south ]
  if (random 100 < east-frequency) [ add-from-east ]
  if (random 100 < west-frequency) [ add-from-west ]
end


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Go
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to go
  
  ; Reset allocated color
  ask patches with [ allocated? ] [
    set allocated? false
    if display-allocation? [
      if ( priority = 2 ) [ set pcolor high-priority-color ]
      if ( priority = 1 ) [ set pcolor low-priority-color ]
    ]
  ]
  
  ; Update ticks-alive
  ask turtles [
    set ticks-alive (ticks-alive + 1)
  ]
  
  ; Add cars
  add-cars-on-frequency 
  
  ; Kill turtles outside roads
  ask (turtles-on patches with [ priority = 0 ]) [ die ]
  
  ; Move it move it
  move-turtles
  
  ; Colorize turtles by speed
  ask turtles with [ speed >= 4 ] [ set color 55 ]
  ask turtles with [ speed < 4 ] [ set color 44 ]
  ask turtles with [ speed = 1 ] [ set color 25 ]
  ask turtles with [ speed = 0 ] [ set color 15 ]
  
  ; Highlight allocated space
  if display-allocation? [
    ask patches with [ allocated? ] [
      set pcolor 14
    ]
  ]
  
  switch-lights
  
  tick
end

to-report move-ahead [ start-patch limit ]

  if (limit = 0) [ report start-patch ]

  let preferred-x ([pxcor] of start-patch + item 0 preferred-turn)
  let preferred-y ([pycor] of start-patch + item 1 preferred-turn)
  let opposite-x ([pxcor] of start-patch + (item 0 preferred-turn) * -1)
  let opposite-y ([pycor] of start-patch + (item 1 preferred-turn) * -1)
  
  let possibilities ([next-patch] of start-patch)
  
  let preferred-patch (patch preferred-x preferred-y)
  let opposite-patch (patch opposite-x opposite-y)
    
  ; Take preferred turn
  if ( member? preferred-patch possibilities ) [
    report move-ahead preferred-patch (limit - 1)
  ]
  ; Alternatively, take anything except the opposite of preferred turn
  if ( not empty? (remove opposite-patch possibilities) ) [
    let alternative (first (remove opposite-patch possibilities))
    report move-ahead alternative (limit - 1)
  ]
  ; Alternatively, take the opposite of preferred turn
  if ( member? opposite-patch possibilities ) [
    report move-ahead opposite-patch (limit - 1)
  ]
  ; Alternatively, when no options, return starting patch
  report start-patch
      
end

to-report get-obstacle-distance [ current max-length ]
  
  if (max-length = 0) [ report 0 ]
  if (empty? [next-patch] of current) [ report 1 ] ; Don't stop before exit

  let options (list)
    
  foreach [next-patch] of current [  
    ifelse (any? turtles-on ?1) or ([allocated?] of ?1) or ([stop?] of ?1) [
      set options (lput 0 options)
    ] [
      let next (get-obstacle-distance ?1 (max-length - 1))
      set options (lput (1 + next) options)
    ]  
  ]
  
  report min options
  
end

to-report allocate-patches [ start-patch limit ] ; Reports the distance to the nearest obstacle

  if (limit = 0)
    or ( (any? other turtles-on start-patch) and ([patch-type] of start-patch != "spawn") )
    or ([allocated?] of start-patch)
    or ([stop?] of start-patch)
    [ report 0 ]
    
  ; Allocate this field
  ask start-patch [ set allocated? true ]

  let preferred-x ([pxcor] of start-patch + item 0 preferred-turn)
  let preferred-y ([pycor] of start-patch + item 1 preferred-turn)
  let opposite-x ([pxcor] of start-patch + (item 0 preferred-turn) * -1)
  let opposite-y ([pycor] of start-patch + (item 1 preferred-turn) * -1)
  
  let possibilities ([next-patch] of start-patch)
  let preferred-patch (patch preferred-x preferred-y)
  let opposite-patch (patch opposite-x opposite-y)
    
  ; Take preferred turn
  if ( member? preferred-patch possibilities ) [
    report 1 + allocate-patches preferred-patch (limit - 1)
  ]
  ; Alternatively, take anything except the opposite of preferred turn
  if ( not empty? (remove opposite-patch possibilities) ) [
    let alternative (first (remove opposite-patch possibilities))
    report 1 + allocate-patches alternative (limit - 1)
  ]
  ; Alternatively, take the opposite of preferred turn
  if ( member? opposite-patch possibilities ) [
    report 1 + allocate-patches opposite-patch (limit - 1)
  ]
  ; Alternatively, when no options (end of road), move 1 field forward to die
  report 1
  
end

to move-turtles
  
  ; 1. Increase speed by acceleration constant
  ask turtles [
    set speed (speed + acceleration)
    set speed (min list ([max-speed] of patch-here) (speed + acceleration))
  ]
  
  ; 2. Allocate patches at lookahead distance, or until the nearest obstacle
  ask (turtles-on patches with [ priority = 2 ]) [
    let nearest-obstacle (allocate-patches patch-here (speed * allocation-factor))
    set speed min (list (nearest-obstacle - 1) speed)
    set speed max (list speed 0)
  ]
  ask (turtles-on patches with [ priority = 1 ]) [
    let nearest-obstacle (allocate-patches patch-here (speed * allocation-factor))
    set speed min (list (nearest-obstacle - 1) speed)
    set speed max (list speed 0)
  ]
  
  ; 3. No random speed variations
  ; noop
  
  ; 4. Move turtles
  ask turtles [
    let target-patch (move-ahead patch-here speed)
    facexy ([pxcor] of target-patch) ([pycor] of target-patch)
    setxy ([pxcor] of target-patch) ([pycor] of target-patch)
  ]
  
end


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Switch lights
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to switch-lights
  if ( intersection = "traffic-lights" ) [
    
    let red-lights (patches with [ patch-type = "light" and light-color = red ])
    let orange-lights (patches with [ patch-type = "light" and light-color = orange ])
    let green-lights (patches with [ patch-type = "light" and light-color = green ])
  
    if (ticks mod (green-length + orange-length)) = 0 [
          
      ifelse lights-horizontal? [
        draw-traffic-lights 1 2 low-priority-color high-priority-color
      ] [
        draw-traffic-lights 2 1 high-priority-color low-priority-color
      ]
      set lights-horizontal? (not lights-horizontal?)
    
      ask red-lights [
        set stop? false
        set light-color green
      ]    
      ask orange-lights [
        set stop? true
        set light-color red
      ]
      ask green-lights [
        set stop? true
        set light-color red
      ]
      
    ]
    
    if (ticks mod (green-length + orange-length)) = green-length [
     
      ask green-lights [
        set stop? true
        set light-color orange
      ]
      
    ]
    
    ask patches with [ patch-type = "light" ] [
      set pcolor light-color
    ]
    
  ]
end


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Export
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to export
  export-plot "Average time on road" (word "plots/" intersection "_" north-frequency "_" east-frequency "_" south-frequency "_" west-frequency ".csv")
end
@#$#@#$#@
GRAPHICS-WINDOW
295
53
785
564
-1
-1
4.0
1
6
1
1
1
0
1
1
1
0
119
0
119
1
1
1
ticks
30.0

BUTTON
15
18
78
51
NIL
startup
NIL
1
T
OBSERVER
NIL
I
NIL
NIL
1

BUTTON
86
18
158
51
go-once
go
NIL
1
T
OBSERVER
NIL
G
NIL
NIL
1

BUTTON
165
18
220
51
NIL
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
463
17
628
50
north-frequency
north-frequency
0
50
43
1
1
NIL
HORIZONTAL

SLIDER
457
567
629
600
south-frequency
south-frequency
0
50
27
1
1
NIL
HORIZONTAL

SLIDER
257
240
290
390
west-frequency
west-frequency
0
50
23
1
1
NIL
VERTICAL

SLIDER
17
161
222
194
acceleration
acceleration
1
5
1
1
1
m/(s^2)
HORIZONTAL

SLIDER
793
241
826
391
east-frequency
east-frequency
0
50
33
1
1
NIL
VERTICAL

SLIDER
17
332
223
365
radius
radius
3
40
20
1
1
m
HORIZONTAL

SLIDER
16
632
223
665
traffic-lights-gap
traffic-lights-gap
1
10
8
1
1
m
HORIZONTAL

SLIDER
17
205
222
238
allocation-factor
allocation-factor
1
10
3
1
1
NIL
HORIZONTAL

CHOOSER
15
75
220
120
intersection
intersection
"roundabout" "roundabout-quick-right" "traffic-lights"
2

PLOT
861
19
1241
227
Turtles count
NIL
NIL
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"Total" 1.0 0 -16777216 true "" "plot count turtles"
"West" 1.0 0 -955883 true "" "plot count turtles with [origin = \"west\"]"
"North" 1.0 0 -2674135 true "" "plot count turtles with [origin = \"north\"]"
"East" 1.0 0 -13791810 true "" "plot count turtles with [origin = \"east\"]"
"South" 1.0 0 -11085214 true "" "plot count turtles with [origin = \"south\"]"

PLOT
861
238
1240
418
Average time on road
NIL
NIL
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"All" 1.0 0 -16777216 true "" "if (count turtles > 0 ) [ plot mean [ticks-alive] of turtles ]"
"North" 1.0 0 -2674135 true "" "if (count turtles with [origin = \"north\"] > 0 ) [ plot mean [ticks-alive] of turtles with [origin = \"north\"] ]"
"East" 1.0 0 -13791810 true "" "if (count turtles with [origin = \"east\"] > 0 ) [ plot mean [ticks-alive] of turtles with [origin = \"east\"] ]"
"South" 1.0 0 -13840069 true "" "if (count turtles with [origin = \"south\"] > 0 ) [ plot mean [ticks-alive] of turtles with [origin = \"south\"] ]"
"West" 1.0 0 -955883 true "" "if (count turtles with [origin = \"west\"] > 0 ) [ plot mean [ticks-alive] of turtles with [origin = \"west\"] ]"

SLIDER
16
542
224
575
green-length
green-length
1
100
40
1
1
s
HORIZONTAL

SLIDER
16
588
224
621
orange-length
orange-length
1
100
10
1
1
s
HORIZONTAL

BUTTON
1169
429
1238
462
NIL
export
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SWITCH
17
249
223
282
display-allocation?
display-allocation?
1
1
-1000

TEXTBOX
17
139
167
157
General settings:
11
0.0
1

TEXTBOX
18
307
168
325
Roundabout settings:
11
0.0
1

SLIDER
17
373
222
406
roundabout-circle-speed
roundabout-circle-speed
1
20
8
1
1
m/s
HORIZONTAL

SLIDER
17
418
223
451
roundabout-road-speed
roundabout-road-speed
1
20
14
1
1
m/s
HORIZONTAL

TEXTBOX
18
477
168
495
Traffic lights settings:
11
0.0
1

SLIDER
16
499
223
532
traffic-lights-speed
traffic-lights-speed
1
20
14
1
1
m/s
HORIZONTAL

@#$#@#$#@
## WHAT IS IT?

(a general understanding of what the model is trying to show or explain)

## HOW IT WORKS

(what rules the agents use to create the overall behavior of the model)

## HOW TO USE IT

(how to use the model, including a description of each of the items in the Interface tab)

## THINGS TO NOTICE

(suggested things for the user to notice while running the model)

## THINGS TO TRY

(suggested things for the user to try to do (move sliders, switches, etc.) with the model)

## EXTENDING THE MODEL

(suggested things to add or change in the Code tab to make the model more complicated, detailed, accurate, etc.)

## NETLOGO FEATURES

(interesting or unusual features of NetLogo that the model uses, particularly in the Code tab; or where workarounds were needed for missing features)

## RELATED MODELS

(models in the NetLogo Models Library and elsewhere which are of related interest)

## CREDITS AND REFERENCES

(a reference to the model's URL on the web if it has one, as well as any other necessary credits, citations, and links)
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

sheep
false
15
Circle -1 true true 203 65 88
Circle -1 true true 70 65 162
Circle -1 true true 150 105 120
Polygon -7500403 true false 218 120 240 165 255 165 278 120
Circle -7500403 true false 214 72 67
Rectangle -1 true true 164 223 179 298
Polygon -1 true true 45 285 30 285 30 240 15 195 45 210
Circle -1 true true 3 83 150
Rectangle -1 true true 65 221 80 296
Polygon -1 true true 195 285 210 285 210 240 240 210 195 210
Polygon -7500403 true false 276 85 285 105 302 99 294 83
Polygon -7500403 true false 219 85 210 105 193 99 201 83

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

wolf
false
0
Polygon -16777216 true false 253 133 245 131 245 133
Polygon -7500403 true true 2 194 13 197 30 191 38 193 38 205 20 226 20 257 27 265 38 266 40 260 31 253 31 230 60 206 68 198 75 209 66 228 65 243 82 261 84 268 100 267 103 261 77 239 79 231 100 207 98 196 119 201 143 202 160 195 166 210 172 213 173 238 167 251 160 248 154 265 169 264 178 247 186 240 198 260 200 271 217 271 219 262 207 258 195 230 192 198 210 184 227 164 242 144 259 145 284 151 277 141 293 140 299 134 297 127 273 119 270 105
Polygon -7500403 true true -1 195 14 180 36 166 40 153 53 140 82 131 134 133 159 126 188 115 227 108 236 102 238 98 268 86 269 92 281 87 269 103 269 113

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270

@#$#@#$#@
NetLogo 5.0.4
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
<experiments>
  <experiment name="experiment" repetitions="1" runMetricsEveryStep="true">
    <setup>startup</setup>
    <go>go</go>
    <final>export</final>
    <timeLimit steps="1000"/>
    <enumeratedValueSet variable="intersection">
      <value value="&quot;roundabout&quot;"/>
      <value value="&quot;roundabout-quick-right&quot;"/>
      <value value="&quot;traffic-lights&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="north-frequency">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="west-frequency">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="south-frequency">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="east-frequency">
      <value value="10"/>
    </enumeratedValueSet>
  </experiment>
</experiments>
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 1.0 0.0
0.0 1 1.0 0.0
0.2 0 1.0 0.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180

@#$#@#$#@
0
@#$#@#$#@
