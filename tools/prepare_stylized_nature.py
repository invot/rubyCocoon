"""Prepare the supplied environment collections for tools/import_stylized_nature.gd.
python tools/prepare_stylized_nature.py [directory containing the three ZIP files]
Sources are extracted only into ignored build/nature_source; original downloads stay untouched.
The explicit X/Z cuts select complete showcase objects and discard triangles connecting unrelated objects.
"""
import pathlib,json,zipfile,sys
from split_nature import read
SOURCE=pathlib.Path(sys.argv[1]) if len(sys.argv)>1 else pathlib.Path.cwd()
OUT=pathlib.Path('build/nature_split');OUT.mkdir(parents=True,exist_ok=True)
for pack in ['Stylized Nature','Grass','Stylized Rock']:
 with zipfile.ZipFile(SOURCE/('Environment Pack - '+pack+'.zip')) as z:z.extractall(pathlib.Path('build/nature_source')/pack)
cache={}
def export(name,pack,model,box,texture='Texture_BaseColor_v02.png',green=False):
 key=(pack,model)
 if key not in cache:cache[key]=read(pathlib.Path('build/nature_source')/pack/'collection'/('model_%d.obj'%model))
 v,uv,n,faces=cache[key];x0,x1,z0,z1=box
 chosen=[t for t in faces if all(x0<=v[c[0]][0]<=x1 and z0<=v[c[0]][2]<=z1 for c in t)]
 assert chosen,name
 vv=[];tt=[];nn=[]
 for t in chosen:
  for c in t:
   vv.append(v[c[0]]);tt.append(uv[c[1]]);nn.append(n[c[2]])
 lo=[min(p[k] for p in vv) for k in range(3)];hi=[max(p[k] for p in vv) for k in range(3)]
 scale=1/max(hi[k]-lo[k] for k in range(3));off=[(hi[0]+lo[0])/2,lo[1],(hi[2]+lo[2])/2]
 vv=[[(p[k]-off[k])*scale for k in range(3)] for p in vv]
 (OUT/(name+'.json')).write_text(json.dumps(dict(v=vv,uv=tt,n=nn,texture='res://build/nature_source/'+pack+'/collection/'+texture,green=green)))
 print(name,len(chosen))
N='Stylized Nature'
for name,box,green in [
 ('tree_big',(-220,60,-430,-160),True),('tree_oak',(-325,-80,-125,95),False),
 ('tree_pine',(-590,-420,-95,90),True),('tree_round_1',(-470,-255,-330,-115),True),
 ('tree_round_2',(35,310,-245,-10),True),('tree_birch',(-480,-310,80,185),False),
 ('tree_cypress',(135,240,20,125),False),('tree_cypress_slim',(70,130,-45,40),True),
 ('tree_dome',(290,490,-85,115),False),('palm',(205,330,115,255),False),
 ('palm_bent',(320,455,210,340),False),('dead_tree',(-390,-180,145,275),False),
 ('stump',(175,270,265,350),False),('shrub_1',(-160,-55,150,225),False),
 ('shrub_3',(-250,-90,230,345),True),('bush_1',(-70,35,245,330),False),
 ('shrub_4',(-20,85,385,490),True),('shrub_2',(455,555,125,225),False),
 ('bush_2',(-250,-90,230,345),False),('bush_3',(-160,-55,150,225),True)]:export(name,N,0,box,green=green)
R='Stylized Rock';tex='M_Stylized_Rock_v1_Base_color.png'
# Broad, grounded blocks and slabs; the collection's balancing arches and narrow spires are deliberately excluded.
rock_boxes=[(-27,-14,-7,4),(17,27,6,15),(-41,-31,7,15),(-6,3,7,14),(1,14,-5,4),(30,36,7,14)]
names=['field_rock','beach_rock','rock_big','rock_small']+['mountain_%d'%i for i in range(9)]+['stone_%d'%i for i in range(1,6)]
for i,name in enumerate(names):export(name,R,1,rock_boxes[i%len(rock_boxes)],tex)
# Use a broad layered outcrop from the other rock collection, too.
export('mountain_0',R,0,(25,41,-26,-10),'M_Stylized_Rock_v2_Base_color.png')
for i,box in enumerate([(33,43,48,57),(34,40,59,67),(34,40,70,76)]):export('grass_leaf_%d'%i,'Grass',1,box)
