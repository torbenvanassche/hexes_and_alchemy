class_name CommunityProjectState
extends RefCounted

var fieldwork_done := false
var completed := false
var funded := false # Legacy save data; permanent projects no longer offer funding.
var fieldwork_site := Vector3i.MAX
var blueprint_issued := false
