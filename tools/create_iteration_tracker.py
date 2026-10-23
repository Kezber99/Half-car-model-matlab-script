"""Create the offline, macro-free half-car iteration workbook.
Requires XlsxWriter. Run from any directory; no simulation results are invented.
"""
from pathlib import Path
import re
import xlsxwriter
from xlsxwriter.utility import xl_col_to_name as col
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'docs/Half_Car_Iteration_Tracker.xlsx'
N=200; FIRST=5; LAST=FIRST+N-1
w=xlsxwriter.Workbook(OUT);w.set_properties({'title':'Half-car iteration tracker','subject':'Inputs, outputs, validity and graph records','author':'Half-car model team','comments':'Offline workbook. Template inputs only; no simulated outputs prefilled.'})
navy='#153348';teal='#007F7A';light='#EAF4F6';blue='#1764A0';gray='#647483'
F={
 'title':w.add_format({'bold':True,'font_size':23,'font_color':'white','bg_color':navy,'valign':'vcenter'}),
 'subtitle':w.add_format({'font_size':11,'font_color':gray,'text_wrap':True,'valign':'vcenter'}),
 'header':w.add_format({'bold':True,'font_color':'white','bg_color':teal,'text_wrap':True,'valign':'vcenter','border':1,'border_color':'#FFFFFF'}),
 'input':w.add_format({'font_color':blue,'bg_color':'#F0F7FF','valign':'top','num_format':'0.0000'}),
 'text':w.add_format({'font_color':blue,'bg_color':'#F0F7FF','valign':'top','text_wrap':True}),
 'id':w.add_format({'bold':True,'font_color':navy,'bg_color':light}),
 'calc':w.add_format({'font_color':'#34495E','bg_color':'#EFF1F3','num_format':'0.0000','text_wrap':True}),
 'section':w.add_format({'bold':True,'font_color':'white','bg_color':navy,'font_size':12}),
 'label':w.add_format({'bold':True,'font_color':navy,'text_wrap':True,'valign':'top'}),
 'body':w.add_format({'text_wrap':True,'valign':'top','font_color':navy,'font_size':11}),
 'good':w.add_format({'bg_color':'#DDF1E5','font_color':'#15633E'}),
 'bad':w.add_format({'bg_color':'#FCE0DE','font_color':'#A12622'}),
 'warn':w.add_format({'bg_color':'#FFF0CE','font_color':'#855800'}),
 'percent':w.add_format({'num_format':'0.0%','bg_color':'#EFF1F3'}),
 'integer':w.add_format({'font_color':blue,'bg_color':'#F0F7FF','num_format':'0'}),
 'link':w.add_format({'font_color':blue,'underline':1,'bg_color':'#EFF1F3'}),
}
SCHEMAS={};GUIDE={}
sheets={name:w.add_worksheet(name) for name in ['Start Here','Run Index','Vehicle Inputs','Road and Solver','Bumps','Outputs','Compare','Graph Gallery','Field Guide']}
for s in sheets.values():s.hide_gridlines(2);s.set_tab_color(teal);s.set_landscape();s.fit_to_pages(1,0);s.set_paper(9)

def base(name,title,subtitle,headers,widths):
 SCHEMAS[name]=headers
 s=sheets[name];s.merge_range(0,0,0,len(headers)-1,title,F['title']);s.set_row(0,37)
 s.merge_range(1,0,2,len(headers)-1,subtitle,F['subtitle']);s.set_row(1,24);s.set_row(2,20)
 for i,(h,width) in enumerate(zip(headers,widths)):s.write(4,i,h,F['header']);s.set_column(i,i,width)
 s.set_row(4,48);s.freeze_panes(FIRST,1);s.repeat_rows(0,4)
 return s

def table(s,name,headers,n=N):
 s.add_table(4,0,FIRST+n-1,len(headers)-1,{'name':name,'style':'Table Style Medium 2','columns':[{'header':h,'header_format':F['header']} for h in headers]})

def ids(s,n=N):
 for i in range(n):s.write(FIRST+i,0,f'RUN-{i+1:03d}',F['id']);s.set_row(FIRST+i,32)

def validation(s,c,kind='decimal',low=0,positive=False,n=N):
 opts={'validate':kind,'criteria': '>' if positive else '>=','value':low,'ignore_blank':True,'error_type':'stop','error_title':'Check this input','error_message':'Use a numeric value in the units shown.','input_title':'Units matter','input_message':'Read the header comment or Field Guide.'}
 s.data_validation(FIRST,c,FIRST+n-1,c,opts)

def dropdown(s,c,values,n=N):s.data_validation(FIRST,c,FIRST+n-1,c,{'validate':'list','source':values,'ignore_blank':True,'error_type':'stop'})
def fmt_rows(s,cs,n=N):
 for r in range(FIRST,FIRST+n):
  for c in cs:s.write_blank(r,c,None,F['input'])
def comment(s,c,t):
 GUIDE[(s.name,c)]=t
 s.write_comment(4,c,t,{'width':340,'height':130})

# Single source of truth for run identity, reason for the change, and artifacts.
h=['Run ID','Run name','Date / time (with timezone)','Owner','Record type','Parent / baseline ID','What changed?','Hypothesis / expected effect','Code commit / version','Driver / fuel / payload condition','Parameter source / uncertainty','Results folder path / URL','Dashboard image path / URL','MAT data / CSV path / URL','Decision / next action','Open folder','Open graph']
s=base('Run Index','ITERATION REGISTER','One record per run. Blue = enter data; grey = calculated. IDs are preassigned across the input/output sheets; keep each ID with its data when sorting. A blank output is unknown, never a pass.',h,[15,30,27,20,23,19,35,38,23,35,38,42,42,42,42,18,18]);ids(s);table(s,'RunRegister',h)
for r in range(FIRST,LAST+1):
 for c in range(1,15):s.write_blank(r,c,None,F['text'])
 for c,pathc,label in [(15,11,'Open folder'),(16,12,'Open dashboard')]:
  s.write_formula(r,c,f'=IF({col(pathc)}{r+1}="","",HYPERLINK({col(pathc)}{r+1},"{label}"))',F['link'],'')
s.write(FIRST,1,'Template: repository defaults',F['text']);s.write(FIRST,4,'Template / not run',F['text']);s.write(FIRST,6,'Starting input example only; run MATLAB before entering outputs.',F['text']);s.write(FIRST,8,'91a3718 (input baseline)',F['text'])
dropdown(s,4,['Template / not run','Simulation','Physical test']);s.data_validation(FIRST,5,LAST,5,{'validate':'list','source':'=RunIDs'})
comment(s,8,'Record the actual commit plus any uncommitted parameter changes. A commit alone does not capture edited inputs. All input sheets should preserve the exact values used.')
comment(s,12,'Save the MATLAB dashboard as a PNG/PDF, then enter its file path or URL. Relative paths are resolved from the workbook location. This workbook does not recreate time-history graphs from summary metrics.')
w.define_name('RunIDs',"='Run Index'!$A$6:$A$205")

h=['Run ID','Mass convention','m: sprung mass [kg]','m1: front unsprung [kg]','m2: rear unsprung [kg]','Iy: sprung pitch inertia [kg m^2]','a1: CG to front [m]','a2: CG to rear [m]','k1: front WHEEL rate [N/m]','k2: rear WHEEL rate [N/m]','c1: front WHEEL damping [N s/m]','c2: rear WHEEL damping [N s/m]','kt1: front tire rate [N/m]','kt2: rear tire rate [N/m]','Front tire pressure [kPa]','Rear tire pressure [kPa]','Wheelbase [m]','Static front load estimate [N]','Static rear load estimate [N]']
s=base('Vehicle Inputs','VEHICLE INPUTS','Use actual wheel-equivalent rates. One-side and axle-equivalent mass/property conventions must not be mixed. First row contains unvalidated repository examples; other rows are blank.',h,[15,25]+[23]*14+[20,26,26]);ids(s);table(s,'VehicleData',h);fmt_rows(s,range(2,16));dropdown(s,1,['One side','Axle equivalent','Unconfirmed'])
for c in range(2,16):validation(s,c,positive=c not in [10,11,14,15])
for c,t in {1:'One side: half sprung mass/inertia and one wheel per end. Axle equivalent: full sprung mass/inertia and summed axle rates/damping. Verify all inputs use the same representation.',2:'Exclude unsprung masses. Include driver, fuel, and payload consistently.',5:'Pitch inertia of the sprung body about its CG. CG location does not determine inertia.',6:'Sprung-body CG, not uncorrected whole-car CG from scales.',7:'Sprung-body CG. a1+a2 is wheelbase.',8:'Enter WHEEL rate: k_wheel=k_spring*(spring compression/vertical wheel travel)^2. N/mm x 1000 = N/m.',9:'Enter WHEEL rate; use rear spring motion ratio, including installation geometry once.',10:'Wheel-equivalent viscous coefficient, not damping ratio or click setting. c_wheel=c_damper*(shaft travel/wheel travel)^2.',11:'Rear wheel-equivalent damping; compression/rebound behavior is simplified to one coefficient.',12:'Vertical tire stiffness; do not apply suspension motion ratio. 200000 N/m = 200 N/mm.',13:'Estimate or measure at representative pressure/load; no tire-lift-off physics is added.'}.items():comment(s,c,t)
s.write(FIRST,1,'Unconfirmed',F['text']);defaults=[420,53,76,1100,1.4,1.47,10000,13000,10000,10000,200000,200000]
for c,v in enumerate(defaults,2):s.write_number(FIRST,c,v,F['input'])
for r in range(FIRST,LAST+1):
 rr=r+1
 s.write_formula(r,16,f'=IF(COUNT(G{rr}:H{rr})<2,"",G{rr}+H{rr})',F['calc'],'')
 s.write_formula(r,17,f'=IF(OR(COUNT(C{rr}:E{rr},G{rr}:H{rr})<5,SUM(G{rr}:H{rr})<=0),"",9.81*(C{rr}*H{rr}/SUM(G{rr}:H{rr})+D{rr}))',F['calc'],'')
 s.write_formula(r,18,f'=IF(OR(COUNT(C{rr}:E{rr},G{rr}:H{rr})<5,SUM(G{rr}:H{rr})<=0),"",9.81*(C{rr}*G{rr}/SUM(G{rr}:H{rr})+E{rr}))',F['calc'],'')

h=['Run ID','Speed [m/s]','Bump shape','Consecutive bumps?','Requested simulation_dt [s]','Actual simulation_dt [s]','Requested minimum tF [s]','Actual end time [s]','post_bump_time [s]','Convergence requested?','Relative tolerance [fraction]','Absolute tolerances [table order]','Initial flat length [m]','Initial road dx [m]','Trailing flat length used [m]','Trailing road dx [m]','Bump count (from Bumps)','Playback speed','Video FPS','Animation enabled?','Video enabled?','Video filename / path']
s=base('Road and Solver','ROAD, SOLVER & DISPLAY','Enter every active bump in Bumps. Solver timing is independent of playback. Absolute tolerance order: body displacement, pitch, acceleration, front/rear travel, front/rear minimum loads, RMS acceleration.',h,[15,19,23,23,24,24,24,23,22,23,24,48,24,23,26,24,24,20,16,23,21,40]);ids(s);table(s,'RoadSolverData',h);fmt_rows(s,[1,4,5,6,7,8,10,12,13,14,15,17,18]);dropdown(s,2,['cosine','half_ellipse','Measured profile']);dropdown(s,3,['yes','no']);dropdown(s,9,['yes','no']);dropdown(s,19,['yes','no']);dropdown(s,20,['yes','no'])
for c in [1,4,5,6,7,8,10,12,13,14,15,17,18]:validation(s,c,positive=c in [1,4,5,6,7,13,15,17,18])
for r in range(FIRST,LAST+1):
 rr=r+1;s.write_formula(r,16,f'=COUNTIFS(Bumps!$A$6:$A$2005,A{rr},Bumps!$C$6:$C$2005,"<>",Bumps!$D$6:$D$2005,"<>")',F['calc'],0)
for c,v in {1:10,2:'cosine',3:'no',4:.001,6:1,8:1,9:'yes',10:.01,11:'[1e-5 1e-5 0.01 1e-5 1e-5 1 1 0.01]',12:5,13:.1,15:.1,17:.1,18:30,19:'yes',20:'yes',21:'half_car_model.mp4'}.items():s.write(FIRST,c,v,F['input'] if isinstance(v,(int,float)) else F['text'])
comment(s,5,'Read actual_simulation_dt from MATLAB. It can be slightly smaller than requested so the final time falls exactly on the grid.')
comment(s,7,'Read time(end) or results.time(end). Record actual duration: whole-run RMS depends on it.')
comment(s,11,'Paste the eight absolute tolerances in metric order. Mixed units; keep the list unchanged when comparing numerical checks.')
comment(s,17,'Display only. 0.1 means 10x slow motion. This must not change the engineering outputs.')

h=['Run ID','Bump number','Height [m]','Width along road [m]','Flat gap AFTER bump [m]','Profile / measurement notes','Duplicate ID + number?']
s=base('Bumps','BUMP-BY-BUMP ROAD DEFINITION','One row per active bump. Use consecutive numbers starting at 1. N bumps need N−1 gaps: leave the final gap blank. Zero means touching bumps; a blank internal gap is missing data. Same structure is used for a single bump.',h,[18,20,20,25,29,65,30]);table(s,'BumpData',h,2000);fmt_rows(s,[2,3,4],2000)
s.data_validation(FIRST,0,FIRST+1999,0,{'validate':'list','source':'=RunIDs'});validation(s,1,'integer',positive=True,n=2000);validation(s,2,n=2000);validation(s,3,positive=True,n=2000);validation(s,4,n=2000)
for r in range(FIRST,FIRST+2000):
 s.write_blank(r,0,None,F['text']);s.write_blank(r,1,None,F['integer']);s.write_blank(r,5,None,F['text']);rr=r+1
 s.write_formula(r,6,f'=IF(OR(A{rr}="",B{rr}=""),"",IF(COUNTIFS($A$6:$A$2005,A{rr},$B$6:$B$2005,B{rr})>1,"DUPLICATE",""))',F['calc'],'')
for c,v in enumerate(['RUN-001',1,.2,.4]):s.write(FIRST,c,v,F['text'] if c==0 else F['input'])
s.conditional_format(FIRST,6,FIRST+1999,6,{'type':'text','criteria':'containing','value':'DUPLICATE','format':F['bad']})
comment(s,4,'Gap is flat edge-to-edge distance to the NEXT bump. For 3 bumps, fill gaps after bumps 1 and 2; leave bump 3 gap blank. Single bump: leave blank.')

h=['Run ID','Peak abs body displacement [m]','Peak abs pitch [rad]','Peak abs body acceleration [m/s^2]','Peak abs front travel [m]','Peak abs rear travel [m]','Minimum front tire load [N]','Minimum rear tire load [N]','RMS body acceleration [m/s^2]','RMS interval / definition','Convergence result','First contact violation [s]','Physical validation status','Interpretation / trade-off','Peak body displacement [mm]','Peak pitch [deg]','Peak front travel [mm]','Peak rear travel [mm]','Contact screen (calculated)']
s=base('Outputs','OUTPUTS & CONFIDENCE','Paste the eight Value metrics from MATLAB using the SI units shown. Leave unknown values blank. Blue cells are manual records; grey cells convert units or screen contact. A convergence pass does not validate the physics.',h,[15,27,25,30,25,25,26,26,29,37,25,27,29,55,26,23,26,26,40]);ids(s);table(s,'OutputData',h);fmt_rows(s,list(range(1,9))+[11]);
for c in [1,2,3,4,5,8,11]:validation(s,c)
dropdown(s,10,['Not checked','PASS','FAIL']);dropdown(s,12,['Not validated','Compared to test','Validated in stated range'])
for r in range(FIRST,LAST+1):
 rr=r+1
 for target,source,mult in [(14,1,'1000'),(15,2,'180/PI()'),(16,4,'1000'),(17,5,'1000')]:
  s.write_formula(r,target,f'=IF(ISNUMBER({col(source)}{rr}),{col(source)}{rr}*{mult},"")',F['calc'],'')
 s.write_formula(r,18,f'=IF(OR(AND(ISNUMBER(G{rr}),G{rr}<0),AND(ISNUMBER(H{rr}),H{rr}<0)),"VIOLATED - later response unreliable",IF(COUNT(G{rr}:H{rr})=2,"No negative predicted (estimate)","Not entered / incomplete"))',F['calc'],'Not entered / incomplete')
s.write(FIRST,9,'Whole simulation: 0 to actual end time',F['text']);s.write(FIRST,10,'Not checked',F['text']);s.write(FIRST,12,'Not validated',F['text'])
for c in [6,7]:s.conditional_format(FIRST,c,LAST,c,{'type':'cell','criteria':'<','value':0,'format':F['bad']})
s.conditional_format(FIRST,10,LAST,10,{'type':'text','criteria':'containing','value':'FAIL','format':F['bad']});s.conditional_format(FIRST,10,LAST,10,{'type':'text','criteria':'containing','value':'PASS','format':F['good']})
s.conditional_format(FIRST,18,LAST,18,{'type':'text','criteria':'containing','value':'VIOLATED','format':F['bad']})
comment(s,8,'Copy RMS body acceleration (whole run). Keep duration/analysis window consistent: extra quiet settling time can lower RMS.')
comment(s,10,'Copy the MATLAB half-step check result. A numerical PASS can coexist with a contact violation or an unvalidated model.')
comment(s,12,'Only mark validated after a documented physical comparison with acceptance criteria and an operating range. Numerical checks do not establish this.')
comment(s,11,'Optional; copy the warning time from MATLAB. Leave blank if not checked or no violation; use the contact screen to distinguish them.')

# One readable vertical comparison, selected by immutable run ID.
s=sheets['Compare'];s.merge_range('A1:F1','COMPARE TWO ITERATIONS',F['title']);s.set_row(0,38)
s.merge_range('A2:F3','Select Run A and Run B below. Differences are B minus A. Check loading, road, speed, duration, and validity before attributing a change to one parameter. Blank means unknown; it is not zero.',F['subtitle'])
for c,width in enumerate([40,27,17,27,25,60]):s.set_column(c,c,width)
s.set_column('H:M',16)
s.write('B4','Run A',F['label']);s.write('D4','Run B',F['label']);s.write('B5','RUN-001',F['text']);s.write('D5','RUN-002',F['text'])
for cell in ['B5','D5']:s.data_validation(cell,{'validate':'list','source':'=RunIDs'})
for c,t in enumerate(['Input / output','Run A','Units','Run B','Difference (B − A)','How to interpret']):s.write(6,c,t,F['header'])
s.set_row(6,32);s.freeze_panes(7,1)

def lookup(sheet,index,selection):
 letter=col(index)
 return f'IFERROR(IF(COUNTIFS(\'{sheet}\'!$A$6:$A$205,{selection},\'{sheet}\'!${letter}$6:${letter}$205,"<>")=0,"",INDEX(\'{sheet}\'!${letter}$6:${letter}$205,MATCH({selection},\'{sheet}\'!$A$6:$A$205,0))),"")'

row=7;positions={}
def section(title):
 global row
 s.merge_range(row,0,row,5,title,F['section']);s.set_row(row,24);row+=1

def field(label,sheet,index,unit='',meaning=''):
 global row
 s.write(row,0,label,F['label']);s.write(row,2,unit,F['body']);s.write(row,5,meaning,F['body']);s.set_row(row,35)
 for c,sel in [(1,'$B$5'),(3,'$D$5')]:s.write_formula(row,c,'='+lookup(sheet,index,sel),F['calc'],'')
 r=row+1;s.write_formula(row,4,f'=IF(AND(ISNUMBER(B{r}),ISNUMBER(D{r})),D{r}-B{r},"")',F['calc'],'')
 positions[label]=row;row+=1
section('CONTEXT — make comparisons fair')
for args in [('Run name','Run Index',1,'','Template rows are not completed simulations.'),('Record type','Run Index',4,'','Simulation and physical test are different evidence.'),('What changed?','Run Index',6,'','Change one variable for a controlled comparison.'),('Code version','Run Index',8,'','Record edited inputs as well as the commit.'),('Driver / fuel / payload','Run Index',9,'','Use a consistent loading condition.'),('Parameter uncertainty','Run Index',10,'','Measured vs estimated affects confidence.')]:field(*args)
section('VEHICLE INPUTS — wheel-equivalent suspension properties')
for label,index,unit,meaning in [('Mass convention',1,'','One-side vs axle-equivalent must be consistent.'),('Sprung mass',2,'kg','Excludes unsprung mass; includes the chosen driver/payload.'),('Front unsprung mass',3,'kg','Effective represented mass.'),('Rear unsprung mass',4,'kg','Effective represented mass.'),('Sprung pitch inertia',5,'kg m^2','Not determined from CG location.'),('CG to front axle',6,'m','Use sprung-body CG.'),('CG to rear axle',7,'m','Use sprung-body CG.'),('Front wheel rate',8,'N/m','Coil-spring rate times spring motion ratio squared.'),('Rear wheel rate',9,'N/m','Coil-spring rate times spring motion ratio squared.'),('Front wheel damping',10,'N s/m','Damper coefficient times damper motion ratio squared.'),('Rear wheel damping',11,'N s/m','More damping is not automatically better.'),('Front tire stiffness',12,'N/m','Pressure/load-dependent assumption.'),('Rear tire stiffness',13,'N/m','Pressure/load-dependent assumption.'),('Front tire pressure',14,'kPa','Record the test condition.'),('Rear tire pressure',15,'kPa','Record the test condition.')]:field(label,'Vehicle Inputs',index,unit,meaning)
section('ROAD & NUMERICAL SETTINGS — verify the same disturbance')
for label,index,unit,meaning in [('Vehicle speed',1,'m/s','Changes crossing time and axle delay.'),('Bump shape',2,'','Smooth cosine or original half ellipse.'),('Consecutive bumps',3,'yes / no','Inspect the Bumps sheet for per-bump dimensions.'),('Bump count',16,'','Number of rows with height and width supplied.'),('Requested simulation step',4,'s','Smaller time step should be checked for convergence.'),('Actual simulation step',5,'s','Copy the actual MATLAB time spacing.'),('Actual end time',7,'s','Duration affects whole-run RMS.'),('Post-bump time',8,'s','Compare consistent settling intervals.'),('Relative convergence tolerance',10,'fraction','0.01 means 1%, not 0.01%.'),('Absolute tolerances',11,'mixed','Retain the metric order and units.'),('Initial flat length',12,'m','Defines initial road geometry.'),('Initial road resolution',13,'m','Spatial resolution is a separate convergence issue.'),('Trailing flat length',14,'m','Record the actual extent used.'),('Trailing road resolution',15,'m','Record the actual road sampling.'),('Playback speed',17,'ratio','Rendering only; should not change engineering outputs.'),('Video frame rate',18,'fps','Rendering only.')]:field(label,'Road and Solver',index,unit,meaning)
section('ENGINEERING OUTPUTS — compare magnitude and confidence together')
for label,index,unit,meaning in [('Peak body displacement',14,'mm','Converted from the manually entered metre value.'),('Peak pitch',15,'deg','Converted from radians.'),('Peak body acceleration',3,'m/s^2','Magnitude of the dynamic acceleration at sprung CG.'),('RMS body acceleration',8,'m/s^2','Only compare consistent duration / intervals.'),('Peak front travel',16,'mm','Absolute relative travel; check compression/extension in graph.'),('Peak rear travel',17,'mm','Compare with actual available travel, not total stroke alone.'),('Minimum front tire load',6,'N','Below zero violates continuous contact.'),('Minimum rear tire load',7,'N','Positive predicted load is not proof of cornering grip.'),('RMS interval definition',9,'','Record duration / analysis window.'),('Convergence',10,'','Numerical agreement, not physical validation.'),('Contact screen',18,'','Incomplete input never becomes a pass.'),('Physical validation',12,'','Requires a stated operating range and test evidence.'),('First contact violation',11,'s','Copy the warning time if present.'),('Interpretation / trade-off',13,'','Explain what improved and what became worse.')]:field(label,'Outputs',index,unit,meaning)
# Compare status highlighting.
for c in [1,3]:
 s.conditional_format(7,c,row-1,c,{'type':'text','criteria':'containing','value':'VIOLATED','format':F['bad']})
 s.conditional_format(7,c,row-1,c,{'type':'text','criteria':'containing','value':'FAIL','format':F['bad']})
# Compact comparison charts, blank until results are entered.
for start,title,items in [(7,'Body acceleration comparison [m/s²]',['Peak body acceleration','RMS body acceleration']),(25,'Peak suspension travel comparison [mm]',['Peak front travel','Peak rear travel'])]:
 data_row=80 if start==7 else 85
 s.write(data_row,7,'Metric',F['header']);s.write(data_row,8,'Run A',F['header']);s.write(data_row,9,'Run B',F['header'])
 for i,label in enumerate(items,1):
  r=positions[label]+1;s.write(data_row+i,7,label,F['body'])
  for c,source in [(8,'B'),(9,'D')]:s.write_formula(data_row+i,c,f'=IF(ISNUMBER({source}{r}),{source}{r},NA())',F['calc'],'#N/A')
 chart=w.add_chart({'type':'column'})
 for c,label,color in [(8,'Run A','#007F7A'),(9,'Run B','#E69B35')]:
  chart.add_series({'name':label,'categories':['Compare',data_row+1,7,data_row+2,7],'values':['Compare',data_row+1,c,data_row+2,c],'fill':{'color':color},'border':{'none':True}})
 chart.set_title({'name':title});chart.set_y_axis({'major_gridlines':{'visible':True}});chart.set_legend({'position':'bottom'});chart.set_size({'width':610,'height':300});chart.show_blanks_as('gap');s.insert_chart(start,7,chart)
s.merge_range('H45:M46','OPEN THE ORIGINAL GRAPHS — summary charts do not replace the time histories.',F['section'])
for r,sel,label in [(47,'$B$5','Run A dashboard'),(49,'$D$5','Run B dashboard')]:
 s.merge_range(r,7,r,9,label,F['label'])
 path=lookup('Run Index',12,sel)
 s.merge_range(r,10,r,12,f'=IF({path}="","No graph path entered",HYPERLINK({path},"Open dashboard"))',F['link'])
s.merge_range('H53:M58','READ FIRST: a low acceleration number is not sufficient to rank a design. Check tire contact, suspension travel, loading, road geometry, duration, convergence and parameter uncertainty. Use Run Index notes to explain the trade-off.',F['body'])

# Friendly instructions, with an explicit manual recording contract.
s=sheets['Start Here'];s.set_column('A:A',4);s.set_column('B:B',31);s.set_column('C:H',14)
s.merge_range('B2:H3','HALF-CAR ITERATION TRACKER',F['title']);s.merge_range('B5:H6','A lightweight, offline notebook for inputs, outputs, graphs and engineering decisions. No macros, accounts, server, or external workbook connections.',F['subtitle'])
instructions=[('1  Choose an ID','Use RUN-001, RUN-002, etc. The same IDs are already present on all main sheets. RUN-001 contains input examples only: it is marked Template / not run, with no outputs. Change its record type only after a real run.'),('2  Record the reason','In Run Index enter the name, timestamp/timezone, parent ID, code version, exactly what changed, and the loading condition. Never overwrite a completed run to try a new setting.'),('3  Fill the inputs','Use Vehicle Inputs and Road and Solver. Blue cells accept values; grey cells calculate. Rates are wheel-equivalent and SI units are in every header. Record actual values, not only the intended values.'),('4  Describe every bump','Use Bumps: one row per active bump, numbered 1 through N. Enter height, width, and the flat gap after each bump except the last. Zero gaps mean touching bumps. Filter by Run ID to review the sequence.'),('5  Run MATLAB','This workbook is a manual log, not a simulation or automatic MATLAB importer. Run the model, then copy its eight Value metrics into Outputs using m and rad as shown. The workbook also displays mm and degrees.'),('6  Record confidence','Copy convergence status and contact warning time. Negative loads are highlighted. Unknown values stay blank; Not checked is not PASS. Whole-run RMS must use a recorded, consistent duration.'),('7  Keep the evidence','Save the dashboard image, MATLAB results/CSV, and optional video to a run folder. Enter their paths/URLs in Run Index. Keep paths relative to the workbook when sharing the folder, or use accessible shared URLs.'),('8  Compare and interpret','Select two IDs on Compare. Read the inputs and validity flags before judging the output differences. Save a conclusion and next action in Run Index. Original time-history graphs can be opened from the comparison.'),('9  Share and extend','The workbook has 200 prepared runs and 2000 bump rows. Sort entire Excel tables, not individual columns. Keep IDs attached to their records. Save a backup; this is a file, not multi-user database software.')]
for i,(title,body) in enumerate(instructions):
 r=8+i*4;s.merge_range(r,1,r,7,title,F['section']);s.merge_range(r+1,1,r+3,7,body,F['body']);s.set_row(r+1,24)
s.merge_range('B47:H49','Important: parameter defaults are unvalidated examples. Estimated contact checks do not simulate lift-off. A numerical convergence PASS does not establish physical validation. Preserve the original graphs and data for every decision.',F['warn'])
for i,name in enumerate(['Run Index','Vehicle Inputs','Road and Solver','Bumps','Outputs','Compare','Graph Gallery','Field Guide']):s.write_url(51+i,1,f"internal:'{name}'!A1",F['link'],f'Open {name}')
s.print_area('B2:H60')

s=sheets['Graph Gallery'];s.set_column('A:A',3);s.set_column('B:M',12);s.merge_range('B2:M3','GRAPH GALLERY / OPTIONAL SCREENSHOTS',F['title'])
s.merge_range('B5:M7','Paste dashboard screenshots here using Excel Insert → Pictures. Put the run ID, code version and conclusion beside each image. Images are manually managed; use Run Index paths to keep links for all runs. Duplicating this sheet creates more space.',F['subtitle'])
for r in [9,34]:
 s.merge_range(r,1,r,12,'Run ID: __________   Code version: __________   What changed: ____________________',F['label'])
 s.merge_range(r+2,1,r+18,12,'INSERT DASHBOARD SCREENSHOT HERE',w.add_format({'align':'center','valign':'vcenter','font_color':gray,'bg_color':light,'border':1}))
 s.merge_range(r+20,1,r+22,12,'Interpretation / trade-off: ___________________________________________________________',F['body'])

# Field guide, including the units and requirements for every log column.
s=base('Field Guide','FIELD GUIDE','Header comments give input guidance. This sheet lists every field and its purpose; engineering definitions are also in the accompanying report.', ['Sheet','Field','Guidance'],[25,48,110])
entries=[]
for sheet,headers in SCHEMAS.items():
 if sheet=='Field Guide':continue
 for c,header in enumerate(headers):
  guidance=GUIDE.get((sheet,c))
  if not guidance:
   if c==0:guidance='Stable identifier joining the sheets. Keep the ID with the complete row when sorting.'
   elif sheet=='Outputs' and c in range(1,9):guidance='Copy the matching Value from the MATLAB metrics table. Units are shown in the field name. Leave unmeasured/uncomputed outputs blank.'
   elif sheet=='Run Index':guidance='Record enough context to reproduce the run and find its original evidence. Use text or a saved file path as indicated.'
   elif sheet=='Bumps':guidance='One row per active bump. Identify the run and bump order; dimensions are metres. Final gap is blank.'
   elif sheet=='Vehicle Inputs':guidance='Enter the actual property in the shown units, with a consistent mass/property convention. Grey fields are calculated estimates.'
   else:guidance='Record the actual setting used by MATLAB. Grey fields are calculated. Consult the script comments and report for definitions.'
  entries.append((sheet,header,guidance))
for r,entry in enumerate(entries,FIRST):
 for c,t in enumerate(entry):s.write(r,c,t,F['body'])
 s.set_row(r,47)
s.autofilter(4,0,FIRST+len(entries)-1,2)
# Start at the instructions; comparison retains selectable IDs with blank results.
sheets['Start Here'].activate();sheets['Start Here'].set_first_sheet();w.close()
print(f'Created {OUT} ({OUT.stat().st_size:,} bytes)')
