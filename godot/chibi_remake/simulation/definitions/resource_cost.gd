extends RefCounted
## Sparse costs are valid legacy data; only the four spendable resources exist.
const KEYS := ["gold","wood","food","stone"]

static func valid(value) -> bool:
	if not value is Dictionary: return false
	for key in value:
		if key not in KEYS: return false
		var amount = value[key]
		if not (amount is int or amount is float) or not is_finite(float(amount)) or float(amount)<0: return false
	return true
