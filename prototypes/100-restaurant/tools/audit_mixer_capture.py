from pathlib import Path
import json, wave, math
import numpy as np
p=Path(__file__).resolve().parents[1]/'qa/20260929-precision'
with wave.open(str(p/'kitchen-audio.wav')) as w:
    rate=w.getframerate(); channels=w.getnchannels(); width=w.getsampwidth()
    assert width==2
    data=np.frombuffer(w.readframes(w.getnframes()),dtype='<i2').astype(float)/32768
    data=data.reshape(-1,channels)
duration=len(data)/rate
stages=json.loads((p/'kitchen-audio.wav.json').read_text(encoding='utf-8'))['stages']
results=[]
for i,stage in enumerate(stages):
    start=stage['seconds']; end=stages[i+1]['seconds'] if i+1<len(stages) else duration
    signal=data[int((start+.10)*rate):min(len(data),int(end*rate))]
    peak=float(np.max(np.abs(signal))); rms=float(np.sqrt(np.mean(signal**2)))
    results.append(dict(label=stage['label'],peak_dbfs=round(20*math.log10(max(peak,1e-12)),2),rms_dbfs=round(20*math.log10(max(rms,1e-12)),2)))
report={'capture':'Real Godot mixer output, controlled scene; objective signal audit, not human listening approval','duration_seconds':duration,'sample_rate':rate,'channels':channels,'clipped_samples':int(np.sum(np.abs(data)>=.9999)),'stages':results}
assert report['clipped_samples']==0
assert all(r['peak_dbfs']>-60 for r in results[:-1]), results
assert results[-1]['peak_dbfs']<-80,results[-1]
report['status']='PASS'
(p/'audio-mixer-audit.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps(report,ensure_ascii=False))
