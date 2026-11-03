import fs from 'node:fs/promises';import path from 'node:path';
import {Presentation,PresentationFile} from '@oai/artifact-tool';
import {applyPresentationChartFont} from '/Users/qiushi/.codex/plugins/cache/openai-primary-runtime/presentations/26.1017.22136/skills/presentations/container_tools/artifact_tool_utils.mjs';
const W=path.dirname(decodeURIComponent(new URL(import.meta.url).pathname)),B=path.resolve(W,'../..'),U=path.dirname(B),A=path.join(U,'论文结构一致性修正_20261102'),C=path.join(U,'Cao双SP4T复现_20261102');
const O=JSON.parse(await fs.readFile(path.join(A,'Results_cao_l2launch_v3six/seven_state_diagnostic.json')));
const select=JSON.parse(await fs.readFile(path.join(W,'selection.json'))),X=JSON.parse(await fs.readFile(path.join(B,select.analysis,'seven_state_diagnostic.json')));
const p=Presentation.create({slideSize:{width:1600,height:900}}),F='SimSun',colors=['#2476b5','#e1812c','#168c79','#9146ad'];p.theme.defaultFont=F;
const chartOwners=[],tableOwners=[];
const source='Cao et al., Front Inform Technol Electron Eng 2024, 25(12):1695–1707. DOI:10.1631/FITEE.2400379. https://journal.hep.com.cn/fitee/EN/1160039228652446390';
const evidence=`原频段：${A}/Results_cao_l2launch_v3six/seven_state_diagnostic.json；X频段：${B}/${select.analysis}/seven_state_diagnostic.json。幅度20log10|S|，CST原生功率波；固定状态顺序，理想相对相位0,-90,-180,+90度，不排序、不拟合。七个条件组合不等于全16组合。`;
function tx(s,t,x,y,w,h,size=28,color='#000000',bold=false){let q=s.shapes.add({geometry:'textbox',position:{left:x,top:y,width:w,height:h},fill:'none',line:{fill:'none',width:0}});q.text=t;q.text.style={typeface:F,fontSize:size,color,bold};return q;}
function slide(t,sub=''){let s=p.slides.add();s.background.fill='#ffffff';tx(s,t,74,48,1450,80,44,'#000000',true);tx(s,sub,76,140,1445,65,26,'#000000');tx(s,'Cao 双 SP4T 单元  |  结构与数值复现  |  2026.11.02',76,852,1270,28,17,'#000000');tx(s,String(p.slides.items.length).padStart(2,'0'),1440,852,90,28,17,'#000000');s.speakerNotes.text=source+'\n'+evidence;return s;}
async function img(s,file,x,y,w,h,alt){let b=await fs.readFile(file);s.images.add({blob:b.buffer.slice(b.byteOffset,b.byteOffset+b.byteLength),contentType:'image/png',position:{left:x,top:y,width:w,height:h},fit:'contain',alt});s.speakerNotes.text+='\n图片来源：'+file;}
function tab(s,vals,x,y,w,h,widths,sz=24){let t=s.tables.add({rows:vals.length,columns:vals[0].length,left:x,top:y,width:w,height:h,values:vals,columnWidths:widths});t.borders.assign({fill:'#dce3e9',width:1,style:'solid'});for(let i=0;i<vals.length;i++)for(let j=0;j<vals[i].length;j++){let c=t.getCell(i,j);c.fill='#ffffff';c.text.style={typeface:F,fontSize:sz,color:'#000000',bold:i===0};}tableOwners.push(p.slides.items.length);}
function chart(s,title,freq,series,label,x,y,w=700,h=500,min=-180,max=180,step=60,xlabel='频率 / GHz'){
let c=s.charts.add('scatter',{position:{left:x,top:y,width:w,height:h},title,titleTextStyle:{fontSize:25,bold:true,fill:'#000000'},scatterOptions:{style:'lineWithMarkers'},series:series.map((v,i)=>({name:v.name,xValues:freq,values:v.values.map(z=>+z.toFixed(5)),line:{fill:v.color||colors[i%4],width:v.name.includes('限')?1:2},marker:{symbol:'circle',size:5,fill:v.color||colors[i%4]}})),hasLegend:true,legend:{position:'bottom',overlay:false,textStyle:{fontSize:19,fill:'#000000'}},xAxis:{position:'bottom',tickLabelPosition:'low',title:xlabel,min:Math.min(...freq),max:Math.max(...freq),majorUnit:xlabel==='状态序号'?1:.25,numberFormatCode:xlabel==='状态序号'?'0':'0.00',textStyle:{fontSize:19},majorGridlines:{fill:'#e6ebef',width:.5}},yAxis:{crossesAt:min,title:label,min,max,majorUnit:step,numberFormatCode:'0.0',textStyle:{fontSize:19},majorGridlines:{fill:'#e6ebef',width:.7}},chartFill:'#ffffff',plotAreaFill:'#ffffff'});applyPresentationChartFont(c,{fontFamily:F});chartOwners.push(p.slides.items.length);}
const nat=path.join(A,'cao_l2launch_build_v3/native/cao-l2launch-v3-H1V1'),nv=path.join(A,'Results_cao_l2launch_v3screen_structure/native/H1V1');
let s=slide('双极化 2-bit：贴片、耦合槽与两颗 SP4T','论文结构与复现结果汇报  ·  原频段 3.6 GHz → 目标 9–10 GHz');
await img(s,path.join(C,'参考资料/page3-image0.png'),76,212,620,612,'论文Fig.2分层及尺寸图');
tx(s,'论文 Fig. 2',90,810,600,30,20,'#000000');
tab(s,[['从上至下','结构 / 原论文尺寸'],['上层介质与辐射层','F4BM255：1 mm；贴片在下表面'],['空气层 1','5 mm'],['耦合与移相板','RO4003C：0.508 mm'],['该板上 / 下表面','正交开槽地板 / 微带延迟线'],['空气层 2 与背板','8 mm；底部金属反射板']],750,230,774,400,[250,524],24);
tx(s,'周期 P = 33 mm；贴片 W = 25.5 mm\n两颗 SP4T 独立选择 H / V 延迟支路\n每个极化 4 个相位状态；0 个 PIN',750,668,760,140,29,'#173d59',true);
s=slide('CST 分层：辐射贴片与正交耦合槽','原频段修订 v3 的实际 CST 显示副本；为显示内部结构隐藏遮挡层');
await img(s,path.join(nat,'radiator.png'),76,215,700,340,'CST辐射贴片');await img(s,path.join(nv,'aperture_only.png'),824,215,700,340,'CST正交耦合槽');
tx(s,'① 辐射贴片',90,563,650,45,31,'#173d59',true);tx(s,'位于上层介质下表面。入射波激励贴片，\n经空气层耦合到下方开槽地板。',90,617,680,90,27);
tx(s,'② 开槽地板',838,563,650,45,31,'#173d59',true);tx(s,'H 形槽与 I 形槽分别耦合两种极化；\n地板隔开辐射区与背面的移相网络。',838,617,680,90,27);
tx(s,'侧向层叠：上介质 / 贴片 → 5 mm 空气 → 开槽地板 / 下介质 / 延迟线 → 8 mm 空气 → 背板',76,747,1448,78,27,'#000000');
s=slide('CST 分层：移相网络与四态支路','两组开路微带延迟线；图为实际 v3 原频段模型的背面显示');
await img(s,path.join(nv,'rf_only.png'),76,222,940,400,'CST背面H与V延迟网络');
tx(s,'H 网络',790,310,220,45,29,'#173d59',true);tx(s,'V 网络',790,515,220,45,29,'#173d59',true);
tab(s,[['状态','H 支路','V 支路'],['1','L₄','L₁₀'],['2','L₅','L₉'],['3','L₃','L₈'],['4','L₂','L₇']],1050,230,474,340,[142,166,166],26);
tx(s,'③ 微带延迟线：公共端 → SP4T → 一条选通的开路支路',76,651,1430,55,31,'#173d59',true);
tx(s,'同一几何只改变开关状态。长短支路形成不同输入电抗，改变反射相位。\n支路名和顺序固定；芯片引出、折弯及部分槽位置仍包含按论文图补设的尺寸。',76,720,1440,105,28);
s=slide('SP4T 如何实现 2-bit 相位控制','每个 SP4T 用 2 个控制位选择 4 条 RF 通路之一；两个极化分别控制');
await img(s,path.join(C,'参考资料/page3-image1.png'),76,220,740,520,'论文Fig.3SP4T及等效电路');
tx(s,'选择支路 → 改变电长度 → 改变反射相位',850,230,670,100,33,'#173d59',true);
tx(s,'开路微带的输入阻抗：\nZin(l) = −j Z₀ cot(βl)\n\n目标四态相对相位：\n0°、−90°、−180°、+90°\n\n实际相位还受槽耦合、引出、\n关闭支路与芯片寄生影响。',850,345,665,350,30);
tx(s,'原论文电路：ON 为 1.6 Ω + 0.1 nH；OFF 为 120 fF + 0.1 nH；各输出端另有 42 fF 对地。',76,757,1448,65,26,'#000000');
s=slide('论文原频段性能：相位与幅度的目标','左图直接取自原论文 Fig. 8；用于与重建模型区分，非本次 CST 结果');
await img(s,path.join(C,'参考资料/page5-image0.png'),76,211,650,615,'论文Fig.8幅相响应');
tx(s,'3.6 GHz 附近实现双极化四态',790,245,725,75,34,'#173d59',true);
tx(s,'论文以相邻相位差 90° ± 20° 评价。\n\n文中给出的两极化共同工作区间\n约为 3.4–3.8 GHz；幅度约在 −1 dB 以上。\n\n复现时需要同时核对：\n层叠、槽、引出、延迟线尺寸，\n以及 SP4T 端口与寄生电容接法。',790,355,730,330,29);
tx(s,'Fig. 8：(a) V 极化；(b) H 极化。\n实线为相位，虚线为幅度；采用原图双纵轴。',790,730,730,80,25,'#000000');
s=slide('原频段重建：3.6 GHz 的四态分布','最新修订 v3 七态粗算；仅此单频点，不将旧几何扫频曲线混入');
await img(s,path.join(B,'report/assets/original_phasors_times.png'),76,215,1020,600,'原频段v3七态3.6GHz复反射分布');
tab(s,[['3.6 GHz','H','V'],['相对误差最大','32.0°','51.2°'],['相邻误差最大','28.5°','48.9°'],['最低幅度','−1.33 dB','−1.48 dB']],1120,290,404,300,[188,108,108],22);
tx(s,'两极化均未通过 ±20°。\n七态结构核验通过；\n网格仍未收敛。',1120,645,410,150,26,'#173d59',true);
s=slide('原频段重建：相位误差来自哪些状态','相对误差以状态 1 为参考；相邻误差横坐标 i 表示 i → i+1（4 → 1），目标 ±20°');
for(const [i,pol] of ['H','V'].entries()){let m=O.metrics[pol];chart(s,pol+' 极化 · 3.6 GHz',[1,2,3,4],[{name:'相对误差',values:m.phase_error_deg},{name:'循环相邻误差',values:m.cyclic_adjacent_error_deg},{name:'+20°限',values:[20,20,20,20],color:'#929ca7'},{name:'−20°限',values:[-20,-20,-20,-20],color:'#929ca7'}],'误差 / °',76+i*750,230,700,500,-60,60,20,'状态序号');}
tx(s,'四态已经展开，但相位间隔偏离理想值。原频段尚不能标为“论文复现成功”。',76,770,1448,60,29,'#173d59',true);
s=slide('迁移至 9–10 GHz：缩放结构，再调整延迟线','同一候选的七态完整计算；固定缩放 RLC，调整延迟线及 V 公共引出宽度、渐变');
tab(s,[['项目','原频段','X 波段模型'],['尺度因子','3.6 GHz','k = 3.6 / 9.5 = 0.37895'],['周期 / 贴片宽度','33 / 25.5 mm','12.505 / 9.663 mm'],['上下介质板厚','1 / 0.508 mm','0.379 / 0.193 mm'],['两空气层厚度','5 / 8 mm','1.895 / 3.032 mm'],['开关参数 R / L','1.6 Ω / 0.1 nH','1.6 Ω / 0.03789 nH'],['关断 / 对地电容','120 / 42 fF','45.47 / 15.92 fF']],76,218,1448,420,[400,440,608],24);
tx(s,select.geometry,76,676,1448,72,27,'#173d59',true);
tx(s,'RLC 为诊断用数学缩放；不代表 BGSA14GN10 在 X 波段的真实器件性能。',76,780,1448,45,26,'#000000');
for(const pol of ['H','V']){let m=X.metrics[pol];s=slide('X 波段 '+pol+' 极化：完整四态幅度与相对相位','10 个直接求解点；固定另一极化为状态 1，点间连线仅辅助阅读');chart(s,'共极化反射幅度',X.frequency_GHz,m.states.map((n,i)=>({name:n,values:m.amplitude_dB[i]})),'20 log₁₀|S| / dB',76,230,700,490,-3,0,1);chart(s,'相对状态 1 的相位',X.frequency_GHz,m.states.map((n,i)=>({name:n,values:m.relative_phase_deg[i]})),'相对相位 / °',825,230,700,490,-180,180,90);tx(s,`${pol} 四态最低幅度 ${Math.min(...m.minimum_amplitude_dB).toFixed(2)} dB；理想相位 0° / −90° / −180° / +90°（−180°等价于 +180°）。`,76,764,1448,62,25,'#173d59');}
s=slide('X 波段相位误差：超限集中在频带上沿','已审核最佳完整七态；每点取四态最差值，同时约束相对误差与循环相邻误差');
for(const [i,pol] of ['H','V'].entries()){let m=X.metrics[pol];chart(s,pol+' 极化',X.frequency_GHz,[{name:'最大相对误差',values:m.max_relative_error_deg},{name:'最大循环相邻误差',values:m.max_cyclic_adjacent_error_deg},{name:'20°限',values:X.frequency_GHz.map(()=>20),color:'#929ca7'}],'绝对误差 / °',76+i*750,230,700,490,0,40,10);}
tx(s,'结构核验通过。9.5 GHz 为 6/7 态连续两轮 ΔS < 0.03；H1V2 为 0.03169 / 0.01290，未通过。',76,762,1448,70,28,'#173d59');
s=slide('总结：条件四态已完成，整带 2-bit 仍未达标','2026.11.03 阶段总结：优化已结束，保留原频段复现与 X 波段已审核最佳完整七态结果');
const mx=a=>Math.max(...a),mn=a=>Math.min(...a);tab(s,[['指标','原频段 3.6 GHz','X 波段 9–10 GHz 样点'],['H 最大相对 / 相邻误差',`${O.metrics.H.max_combined_error_deg.toFixed(1)}° / ${O.metrics.H.max_cyclic_adjacent_error_deg.toFixed(1)}°`,`${mx(X.metrics.H.max_relative_error_deg).toFixed(1)}° / ${mx(X.metrics.H.max_cyclic_adjacent_error_deg).toFixed(1)}°`],['V 最大相对 / 相邻误差',`${O.metrics.V.max_combined_error_deg.toFixed(1)}° / ${O.metrics.V.max_cyclic_adjacent_error_deg.toFixed(1)}°`,`${mx(X.metrics.V.max_relative_error_deg).toFixed(1)}° / ${mx(X.metrics.V.max_cyclic_adjacent_error_deg).toFixed(1)}°`],['H / V 最低幅度','−1.33 / −1.48 dB',`${mn(X.metrics.H.minimum_amplitude_dB).toFixed(2)} / ${mn(X.metrics.V.minimum_amplitude_dB).toFixed(2)} dB`],['相位 ±20° 与网格收敛','未通过 / 未收敛','未通过 / 中心点6/7态收敛']],76,230,1448,350,[530,420,498],25);
tx(s,'H / V 共同通过相对与循环相位误差 ≤20° 的样点：\n9.0、9.1、9.2、9.3、9.4、9.5、9.625 GHz；仅为离散样点，非连续带宽。',76,610,1448,95,28,'#173d59',true);
tx(s,'限制：9.75–10 GHz 样点相位超限；9.5 GHz 仅 6/7 态满足连续两轮收敛。\n幅度：H / V 均高于粗筛 −3 dB；H 未满足论文 −1 dB，V 在样点满足。\n范围：固定诊断缩放 RLC、七个条件组合；未验证真实器件、全 16 组合及整带收敛。',76,714,1448,118,25);
await fs.mkdir(path.join(W,'renders'),{recursive:true});await (await PresentationFile.exportPptx(p)).save(path.join(W,'draft.pptx'));await fs.writeFile(path.join(W,'requirements.json'),JSON.stringify({requiredNativeChartOwnerSlides:[...new Set(chartOwners)],requiredNativeTableOwnerSlides:[...new Set(tableOwners)]},null,2));for(let i=0;i<p.slides.items.length;i++){let b=await p.export({slide:p.slides.items[i],format:'png',scale:1});await fs.writeFile(path.join(W,'renders',`slide-${i+1}.png`),new Uint8Array(await b.arrayBuffer()));}console.log('Built',p.slides.items.length,'slides');
