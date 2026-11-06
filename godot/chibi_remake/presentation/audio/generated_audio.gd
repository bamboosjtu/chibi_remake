extends RefCounted
## Original procedural tones: no samples, voice recordings, or third-party tracks.
static func stream(key:String,music:=false) -> AudioStreamWAV:
	var out:=AudioStreamWAV.new()
	out.mix_rate=22050;out.format=AudioStreamWAV.FORMAT_16_BITS
	var length:int=88200 if music else 4410
	var pcm:=PackedByteArray();pcm.resize(length*2)
	var frequency:float=220.0+float(absi(key.hash())%7)*55.0
	for i in range(length):
		var t:float=float(i)/22050.0
		var envelope:float=0.12*minf(t*30.0,1.0)*(1.0-float(i)/length)
		var sample:float=sin(TAU*frequency*t)*envelope
		if music:sample=(sin(TAU*220.0*t)+0.5*sin(TAU*330.0*t))*0.045*sin(PI*float(i)/length)
		pcm.encode_s16(i*2,int(sample*32767.0))
	out.data=pcm
	if music:out.loop_mode=AudioStreamWAV.LOOP_FORWARD;out.loop_end=length
	return out
