## Shared numeric and asset constants for the Earth cinematic mission.
class_name MissionConstants
extends RefCounted

const Orbit := preload("res://assets/scripts/orbit/conic_2d.gd")

const TEX_ROCKET := preload("res://assets/sprites/rocket.png")
const TEX_BURN := preload("res://assets/sprites/rocket-burn.png")

const LEO_R := 130.0
const MOON_R := 235.0
const ROCKET_HEADING := 1.5708
const FULL_ELLIPSE_SEGMENTS := 240
const LUNAR_PATH_SEGMENTS := 48
const PERI_EPS := 0.018
