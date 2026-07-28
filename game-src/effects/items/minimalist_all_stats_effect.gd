extends Effect

# Gourmet DLC - Minimalist: card line for the hidden tier-ladder scalers
# (T0 +2, T1 +4, T2 +6, T3 +8 All Stats; +12 each while all 6 held items are
# max tier). Shows the live total currently being applied this run.
# Duck-typed on purpose: no item class references from an Effect subclass
# (cyclic-dependency law) - base effect.gd renders this text_key identically.


func get_text(player_index: int, colored: bool = true) -> String:
	var total: = 0.0
	if player_index >= 0 and player_index != RunData.DUMMY_PLAYER_INDEX:
		total = RunData.get_nb_minimalist_items(player_index) * 2.0
	var signs: = [] if !colored else [Sign.POSITIVE]
	return Text.text("EFFECT_MINIMALIST_ALL", [str(int(round(total)))], signs)
