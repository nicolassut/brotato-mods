extends Node2D

# Gourmet ecosystem - the Hub avatar's visual root. The REAL player idle/move
# animations (player_idle.tres / player_move.tres) drive the subtree below
# this node; their method tracks call play_step_sound on the animation root,
# which in a run is player.gd. The hub avatar keeps the visual bounce but
# stays quiet (footstep sounds are a later polish pass).


func play_step_sound() -> void :
	pass
