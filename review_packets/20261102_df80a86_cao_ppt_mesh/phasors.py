from pathlib import Path
import json,numpy as np,matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib import font_manager
B=Path(__file__).resolve().parents[2];A=B.parent/'论文结构一致性修正_20261102'
d=json.loads((A/'Results_cao_l2launch_v3six/seven_state_diagnostic.json').read_text())
font_manager.fontManager.addfont('/System/Library/Fonts/Supplemental/Times New Roman.ttf')
plt.rcParams.update({'font.family':'Times New Roman','font.size':20,'text.color':'black','axes.labelcolor':'black','xtick.color':'black','ytick.color':'black'})
fig,axs=plt.subplots(1,2,figsize=(11,6),subplot_kw={'projection':'polar'})
colors=['#2476b5','#e1812c','#168c79','#9146ad']
for ax,pol in zip(axs,['H','V']):
 m=d['metrics'][pol]
 for st,ph,amp,col in zip(m['states'],m['relative_phase_deg'],m['amplitude_dB'],colors):
  a=np.deg2rad(ph);r=10**(amp/20);ax.plot([a,a],[0,r],color=col,lw=3,marker='o',markevery=[1],label=f'{st}: {ph:.1f}°, {amp:.2f} dB')
 ax.set_ylim(0,1.05);ax.set_yticks([.25,.5,.75,1]);ax.tick_params(labelsize=17);ax.grid(alpha=.3);ax.set_title(pol+' polarization',pad=27,fontsize=23);ax.legend(loc='upper center',bbox_to_anchor=(.5,-.20),fontsize=16,frameon=False,handlelength=1)
fig.subplots_adjust(left=.05,right=.96,top=.87,bottom=.31,wspace=.35)
fig.savefig(B/'report/assets/original_phasors_times.png',dpi=200,bbox_inches='tight');plt.close(fig)
