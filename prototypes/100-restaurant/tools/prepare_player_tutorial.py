"""Prepare licensed gameplay audio and optional player tutorial subtitles.

Optionally trims identical native startup frames from audio and video, then
applies uniform gain and short endpoint fades. SRT timestamps follow the cut;
no generated audio or altered gameplay timing.
"""
from pathlib import Path
import array, hashlib, json, math, sys, wave
if len(sys.argv) not in (5,6): raise SystemExit("Usage: prepare_player_tutorial.py <source.wav> <processed.wav> <qa-directory> <demo-directory> [trim-start-frames]")
source=Path(sys.argv[1]); target=Path(sys.argv[2]); qa=Path(sys.argv[3]); demo=Path(sys.argv[4])
timeline=json.loads((qa/'video/timeline.json').read_text())
trim_frames=int(sys.argv[5]) if len(sys.argv)==6 else 0
assert trim_frames>=0
trim_seconds=trim_frames/timeline['fps']
with wave.open(str(source),'rb') as w:
 channels=w.getnchannels();rate=w.getframerate();width=w.getsampwidth();frames=w.getnframes();raw=w.readframes(frames)
assert width==2 and channels==2 and rate==48000
raw_source_seconds=frames/rate
trim_samples=round(trim_seconds*rate)
raw=raw[trim_samples*channels*width:]; frames-=trim_samples
assert frames>0
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
report={'source_seconds':frames/rate,'raw_source_seconds':raw_source_seconds,'trim_start_native_frames':trim_frames,'trim_seconds':trim_seconds,'sample_rate':rate,'channels':channels,'source_peak_dbfs':20*math.log10(peak/32767),'source_rms_dbfs':20*math.log10(rms/32767),'source_clipped_samples':clipping,'gain_db':20*math.log10(gain),'fade_seconds':.12,'final_peak_dbfs':20*math.log10(final_peak/32767),'final_clipped_samples':sum(abs(x)>=32767 for x in samples),'source_pcm_sha256':hashlib.sha256(raw).hexdigest(),'processed_wav_sha256':hashlib.sha256(target.read_bytes()).hexdigest(),'note':'Only matching native startup-frame trim, uniform gain and endpoint fades; licensed native game recordings, no generated effects, music or voiceover.'}
(qa/'audio-audit.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n');print(json.dumps(report,ensure_ascii=False))
entries=timeline['timeline']; startup_frame=1/timeline['fps']-trim_seconds
def stamp(value):
 ms=round(value*1000);h,ms=divmod(ms,3600000);m,ms=divmod(ms,60000);s,ms=divmod(ms,1000);return f'{h:02d}:{m:02d}:{s:02d},{ms:03d}'
parts=[]
for i,entry in enumerate(entries):
 start=max(0,entry['seconds']+startup_frame);end=(entries[i+1]['seconds'] if i+1<len(entries) else timeline['duration'])+startup_frame
 words="饭店小游戏演示" if i==0 else entry["caption"]
 if words.startswith("这次故意继续大火"):
  words += "（积汽等待 · 5 倍速）"
 parts.append(f'{i+1}\n{stamp(start)} --> {stamp(end)}\n{words}\n')
(demo/'厨房游戏全流程演示.srt').write_text('\n'.join(parts),encoding='utf-8')
