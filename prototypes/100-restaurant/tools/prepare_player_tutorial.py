"""Prepare licensed gameplay audio and optional player tutorial subtitles.

Applies uniform gain and short endpoint fades; does not generate audio or
change timing. The Movie Maker startup frame is retained in SRT timestamps.
"""
from pathlib import Path
import array, hashlib, json, math, sys, wave
if len(sys.argv)!=5: raise SystemExit("Usage: prepare_player_tutorial.py <source.wav> <processed.wav> <qa-directory> <demo-directory>")
source=Path(sys.argv[1]); target=Path(sys.argv[2]); qa=Path(sys.argv[3]); demo=Path(sys.argv[4])
with wave.open(str(source),'rb') as w:
 channels=w.getnchannels();rate=w.getframerate();width=w.getsampwidth();frames=w.getnframes();raw=w.readframes(frames)
assert width==2 and channels==2 and rate==48000
samples=array.array('h',raw);peak=max(abs(x) for x in samples);rms=math.sqrt(sum(x*x for x in samples)/len(samples));clipping=sum(abs(x)>=32767 for x in samples)
assert peak>0 and clipping==0
gain=min(4., 32767*10**(-5/20)/peak)
fade=int(rate*.12)
for i in range(len(samples)):
 t=i//channels;factor=min(1,t/fade,(frames-1-t)/fade)
 samples[i]=round(samples[i]*gain*max(0,factor))
with wave.open(str(target),'wb') as w:
 w.setnchannels(channels);w.setsampwidth(width);w.setframerate(rate);w.writeframes(samples.tobytes())
final_peak=max(abs(x) for x in samples)
report={'source_seconds':frames/rate,'sample_rate':rate,'channels':channels,'source_peak_dbfs':20*math.log10(peak/32767),'source_rms_dbfs':20*math.log10(rms/32767),'source_clipped_samples':clipping,'gain_db':20*math.log10(gain),'fade_seconds':.12,'final_peak_dbfs':20*math.log10(final_peak/32767),'final_clipped_samples':sum(abs(x)>=32767 for x in samples),'source_pcm_sha256':hashlib.sha256(raw).hexdigest(),'processed_wav_sha256':hashlib.sha256(target.read_bytes()).hexdigest(),'note':'Only uniform gain and endpoint fades; licensed native game recordings, no generated effects, music or voiceover.'}
(qa/'audio-audit.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n');print(json.dumps(report,ensure_ascii=False))
timeline=json.loads((qa/'video/timeline.json').read_text());entries=timeline['timeline']; startup_frame=1/timeline['fps']
def stamp(value):
 ms=round(value*1000);h,ms=divmod(ms,3600000);m,ms=divmod(ms,60000);s,ms=divmod(ms,1000);return f'{h:02d}:{m:02d}:{s:02d},{ms:03d}'
parts=[]
for i,entry in enumerate(entries):
 start=entry['seconds']+startup_frame;end=(entries[i+1]['seconds'] if i+1<len(entries) else timeline['duration'])+startup_frame
 parts.append(f'{i+1}\n{stamp(start)} --> {stamp(end)}\n{entry["caption"]}\n')
(demo/'厨房游戏全流程演示.srt').write_text('\n'.join(parts),encoding='utf-8')
