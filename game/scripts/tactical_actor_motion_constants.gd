extends RefCounted
# MIT. Presentation of tactical groups, keyed by actor id: each group shows up
# to four soldiers who sprint to the new source cell, brake onto it and wait
# for the next step; planted feet never slide (stride phase follows distance).
# Melee: strikes and recoils; every man lost falls, one after another, in one
# of three falls. Dynamite: the planter runs to the slot, kneels, sets the box
# and lights the fuse. Boarding: run to the wagon, climb its side, mantle.
# Reads the combat model only, on the shared50Hz visual step; presentation
# RNG is separate from the source. Authored presentation: the original draws
# field actors as map tiles (WDECOR cputmap98) and roof actors as sprites
# 10+cell (0x5126); its facing and in-between motion are not decoded, so none
# of this claims original behaviour.
const Geometry = preload("res://scripts/tactical_effects_geometry.gd")
const Rig = preload("res://scripts/tactical_trooper_rig.gd")
const Poses = preload("res://scripts/tactical_trooper_poses.gd")
const Mammoth = preload("res://scripts/tactical_mammoth_poses.gd")
const Beast = preload("res://scripts/tactical_mammoth_motion.gd")
const STEP := 1.0/50.0
const SPRINT := 22.0 # source: authored top speed, logical px/s (~1.7 body heights/s).
const ACCEL := 140.0 # source: authored, logical px/s².
const BRAKE := 110.0 # source: authored, logical px/s².
const CLIMB := 24.0 # source: authored climbing speed up a wagon side, logical px/s.
const RUNG := 3.0 # source: authored climbing step, logical px.
const MANTLE := 4 # index of the mantle among the climb frames, after the four rung frames.
const BOX_HALF := 1.75 # half the drawn box's width, logical px (see _draw_box).
const LADDER_GRAB := 1.5 # source: authored; the rails stand this far above the roof, a grab handle.
const KNEEL_CROUCH := 1.0 # source: measured on the rig; beyond ~1.2 its feet sink below the ground line and the coat bunches.
const HULL_DROP := 4.0 # source: measured on the wagon sprites; the cap falls ~10px at the hull end, the roof's own curve under 3.
const MANTLE_START := 8.8 # source: Poses.hand(4): the mantle's fist is this high above its feet, logical px.
const MANTLE_SINK := 0.6 # source: authored; the rear foot ends this far under the roof surface, the rig then stands on it.
const MANTLE_SWING := 1.5 # source: authored; the hull-ward move finishes this much sooner than the haul.
const LAND := 4.0 # source: authored; the mantle lands this far inside the ladder, on the flat roof (the roof's end drops away at the ladder).
const FALL_REACH := 14.0 # source: measured, logical px; length of a lying soldier (Poses fall frames, 12-14).
const SETTLE := 0.12 # source: authored; the runner gathers his feet this long before the ladder, s.
const MANTLE_HOLD := 0.6 # source: authored share of the rise spent in the mantle sprite before standing.
const WAGON_SIDE := 25.0 # source: roof 38 above the top train baseline 63, logical px.
const MAMMOTH_SPEED := 14.0 # source: authored heavy gait, logical px/s.
const STRIDE_PX := Rig.STRIDE/Rig.PER # one step of the rig, logical px.
# Riders stepping off a howdah (0x123a): seconds on each of the 5 dismount frames (stand on the
# rim, leg over, hang from it, drop, land). They climb down the howdah's rear end, behind the
# rump, where the sprite shows him clear of the flank; HANG_OUT logical px outside the rim end (authored).
const DISMOUNT := [0.25,0.22,0.3,0.14,0.22]
const HANG_OUT := 2.0
const REAR := 3.0 # source: authored, logical px a toppling rider starts behind his seat, over the howdah's rear rim.
const DISMOUNT_GAP := 0.5 # source: authored, s between two riders stepping off the same howdah.
const VISIBLE := 4 # source: authored most soldiers drawn per group.
# Formation offsets, logical px; negative y stands farther from the viewer.
const FIELD_FORMATION := [Vector2(1,0),Vector2(-6,-3),Vector2(6.5,-1.5),Vector2(-0.5,-5.5)]
const ROOF_FORMATION := [Vector2(0,0),Vector2(-4.5,0),Vector2(4.5,0),Vector2(-2,0)]
const STRIKE := 0.35 # source: authored blow duration, s.
const RECOIL := 0.35 # source: authored hit reaction, s.
const ENGAGED := 1.2 # source: authored hold-facing after a melee, s.
const NEXT_FALL := 0.3 # source: authored delay between successive deaths, s.
const LIE := 3.0 # source: authored time a casualty stays down, s.
const FADE := 0.6 # source: authored fade of bodies and merged groups, s.
# Deaths play the sprite falls of Poses over DEATH s (kind 1 pitches forward,
# the others are thrown back), the last frame landing at IMPACT.
const DEATH := 0.9 # source: authored fall duration, s.
const IMPACT := 0.85 # source: authored fraction of DEATH when the body lands.
# Plant sequence, s (authored): kneel, set the box, light the fuse, rise.
const KNEEL := 0.25
const SET := 0.35
const LIGHT := 0.35
const RISE := 0.25
