extends RefCounted
## Traversal of the staggered rectangular ownership cells used by
## cell_of_px. Work scales with crossed grid cells, not world-pixel distance.
static func cells(a: Vector2, b: Vector2, width: float, rows: int, columns: int) -> PackedInt64Array:
	var result:=PackedInt64Array();var half:=width*0.5;var step:=width*0.25
	var low:=roundi((minf(a.y,b.y)-half)/step)
	var high:=roundi((maxf(a.y,b.y)-half)/step)
	var dy:=b.y-a.y
	for row in range(low,high+1):
		var begin:=0.0;var end:=1.0
		if absf(dy)>0.000001:
			var y0: float=half+(row-0.5)*step
			var y1: float=half+(row+0.5)*step
			var t0: float=(y0-a.y)/dy;var t1: float=(y1-a.y)/dy
			begin=maxf(0.0,minf(t0,t1));end=minf(1.0,maxf(t0,t1))
			if begin>end:continue
		var x0:=lerpf(a.x,b.x,begin);var x1:=lerpf(a.x,b.x,end)
		var offset: float=half+half*(row&1)
		var first:=clampi(floori((minf(x0,x1)-offset)/width+0.5),0,rows-1)
		var last:=clampi(floori((maxf(x0,x1)-offset)/width+0.5),0,rows-1)
		for column in range(first,last+1):result.append(column*columns+clampi(row,0,columns-1))
	return result
