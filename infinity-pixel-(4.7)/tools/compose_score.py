"""Inity Pixel · Passos do Refúgio. Original synthesized score; no samples.
120 BPM, D minor. 56 bars / 112 s: intro 4, A 16, A'16, bridge 8, return 8, turnaround 4.
Run with Python + numpy. Fixed seed preserves reproducibility.
"""
from pathlib import Path
import numpy as np, wave, json
R=Path(__file__).resolve().parents[1];OUT=R/'assets/audio';OUT.mkdir(parents=True,exist_ok=True)
SR=32000;BEAT=.5;BAR=2.;N=int(112*SR);rng=np.random.default_rng(41)
chords=[[50,57,62,65],[46,53,58,62],[41,48,57,60],[48,55,60,64]]
motifs=[[74,77,81,79,77,74,72,74],[70,74,77,74,72,69,70,74],[69,72,77,76,72,69,67,69],[72,76,79,77,76,72,69,72]]
def note(midi,dur,kind):
 t=np.arange(int(dur*SR))/SR;f=440*2**((midi-69)/12);attack=np.minimum(t/(.055 if kind=='pad' else .016),1)
 end=np.minimum((dur-t)/(.22 if kind=='pad' else .08),1)
 if kind=='flute':y=np.sin(2*np.pi*f*t + .018*np.sin(2*np.pi*5*t))+.16*np.sin(4*np.pi*f*t);env=attack*end*np.exp(-t/(dur*3))
 elif kind=='pad':y=np.sin(2*np.pi*f*t)+.22*np.sin(2*np.pi*f*1.003*t)+.12*np.sin(4*np.pi*f*t);env=attack*end*.7
 else:y=np.sin(2*np.pi*f*t)+.32*np.sin(2*np.pi*f*2.01*t)+.10*np.sin(2*np.pi*f*3.99*t);env=attack*end*np.exp(-t/(.22 if kind=='pluck' else .65))
 return y*env

def score(mode):
 mix=np.zeros((N,2),dtype=np.float64)
 def put(t,y,amp,pan=0):
  j=int(t*SR);idx=(np.arange(len(y))+j)%N
  mix[idx,0]+=y*amp*np.sqrt((1-pan)/2);mix[idx,1]+=y*amp*np.sqrt((1+pan)/2)
 for bar in range(56):
  section=0 if bar<4 else 1 if bar<20 else 2 if bar<36 else 3 if bar<44 else 4 if bar<52 else 5
  root=chords[bar%4];energy=[.30,.65,.82,.48,1,.4][section]
  if mode=='calm':energy*=.54
  if mode=='combat':energy=max(energy,.7)
  for k,m in enumerate(root):put(bar*BAR,note(m+12,2.15,'pad'),.032*energy,(k-1.5)/3)
  for beat in [0,2]:put(bar*BAR+beat*BEAT,note(root[0]-12,.8,'bass'),.15*energy,-.07)
  # Motif is introduced after four bars, recast in the middle and restated near end.
  if section in [1,2,4]:
   melody=motifs[bar%4]
   for k,m in enumerate(melody):
    if section==2 and k%3==0:m+=12
    if mode=='calm' and k%2:continue
    put(bar*BAR+k*.25,note(m,.44 if k<7 else .65,'flute'),.082*energy,.12)
  elif section in [0,3,5]:
   for k in range(2):put(bar*BAR+k,.0+note(root[k+1]+12,1.45,'flute'),.062*energy,.22)
  # Syncopated mallet response; rhythm expands instead of looping a pasted block.
  for k in range(8):
   if mode=='calm' and k%2:continue
   put(bar*BAR+k*.25,note(root[k%4]+24,.5,'pluck'),.055*energy,(-.5 if k%2 else .5))
  beats=[0,2] if mode=='calm' else [0,1.5,2,3.5]
  if section==0:beats=[0]
  for b in beats:
   t=np.arange(int(.32*SR))/SR;drum=np.sin(2*np.pi*(62*t+55*.028*(1-np.exp(-t/.028))))*np.exp(-t*16)*np.minimum(t/.003,1)
   put(bar*BAR+b*BEAT,drum,.21*energy)
  if section>0:
   for k in range(8 if mode!='calm' else 4):
    t=np.arange(int(.065*SR))/SR;n=rng.normal(0,1,len(t));n=np.diff(n,prepend=0);n=n*np.exp(-t*70)*np.minimum(t/.003,1)
    put(bar*BAR+k*(.25 if mode!='calm' else .5),n,.013*energy,.45 if k%2 else -.45)
  if section==2 and bar%4==3 and mode!='calm':
   for k in range(4):put(bar*BAR+1.5+k*.125,note(43+k*2,.16,'bass'),.06,-.3)
 # Gentle stereo echoes, circular tails preserve continuity through the seam.
 for delay,gain in [(.1875,.14),(.375,.09),(.625,.055)]:mix+=np.roll(mix[:,::-1].copy(),int(delay*SR),axis=0)*gain
 # Very short endpoint ramps remove numerical edge discontinuities.
 ramp=np.linspace(0,1,int(.018*SR));mix[:len(ramp)]*=ramp[:,None];mix[-len(ramp):]*=ramp[::-1,None]
 return mix
stats={}
def save(name,a):
 peak=float(np.max(np.abs(a)));a=a*(.72/max(peak,1e-9));pcm=(np.clip(a,-1,1)*32767).astype('<i2')
 with wave.open(str(OUT/name),'wb') as w:w.setnchannels(2);w.setsampwidth(2);w.setframerate(SR);w.writeframes(pcm.tobytes())
 stats[name]={'seconds':len(a)/SR,'sample_rate':SR,'peak_dbfs':float(20*np.log10(np.max(np.abs(a)))),'rms_dbfs':float(20*np.log10(np.sqrt(np.mean(a*a)))),'clipped_samples':int(np.sum(np.abs(pcm)>=32767)),'seam_jump':float(np.max(np.abs(a[0]-a[-1])))}
for mode in ['principal','calm','combat']:save('refugio_'+mode+'.wav',score(mode))
for won in [True,False]:
 dur=4.;a=np.zeros((int(dur*SR),2));notes=[74,77,81,86] if won else [74,72,69,62]
 for k,m in enumerate(notes):
  n=note(m,1.6,'flute');j=int(k*.45*SR);a[j:j+len(n),:]+=n[:,None]*.13
 a[-int(.3*SR):]*=np.linspace(1,0,int(.3*SR))[:,None];save('victory.wav' if won else 'defeat.wav',a)
# Soft stone strike/domestication chime are generated with the same instruments.
for name,m in [('strike.wav',43),('bond.wav',81)]:
 a=note(m,.24 if name=='strike.wav' else .8,'pluck');save(name,np.stack([a,a],axis=1))
(R/'docs/ac1/evidence/audio_metrics.json').write_text(json.dumps(stats,indent=2))
print(json.dumps(stats,indent=2))
