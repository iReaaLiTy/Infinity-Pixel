"""Original editable low-poly scene sources. Rebuild with Python 3 (no packages)."""
from pathlib import Path
import random, math, re
R=Path(__file__).resolve().parents[1]
if (R/'scenes/world/world_regions.tscn').exists():
 raise SystemExit('Spec 012: use tools/build_first_map.gd, then build_collisions.ps1 and bake_navmesh.gd. Legacy arena generator is disabled to preserve the authored map and current actors.')
class Scene:
 def __init__(self,name,script=None): self.res=[];self.nodes=[];self.ext=[];self.n=0;self.node(name,'Node3D',None,{'script':'ExtResource("script")'} if script else {});self.name=name;self.ext=[f'[ext_resource type="Script" path="{script}" id="script"]'] if script else []
 def node(self,name,kind,parent='.',props=None): self.nodes.append(f'[node name="{name}" type="{kind}"'+(f' parent="{parent}"' if parent is not None else '')+']\n'+'\n'.join(f'{k} = {v}' for k,v in (props or {}).items()))
 def resource(self,kind,props): self.n+=1;i=f'r{self.n}';self.res.append(f'[sub_resource type="{kind}" id="{i}"]\n'+'\n'.join(f'{k} = {v}' for k,v in props.items()));return f'SubResource("{i}")'
 def mat(self,col,emission=False):
  c=[int(col[i:i+2],16)/255 for i in (0,2,4)];p={'albedo_color':f'Color({c[0]}, {c[1]}, {c[2]}, 1)','roughness':'.88'}
  if emission:p.update({'emission_enabled':'true','emission':f'Color({c[0]}, {c[1]}, {c[2]}, 1)','emission_energy_multiplier':'1.5'})
  return self.resource('StandardMaterial3D',p)
 def shape(self,name,kind,pos,size,mat,parent='.',rot=None):
  if kind=='box': mesh=self.resource('BoxMesh',{'size':vec(size)})
  elif kind=='orb':mesh=self.resource('SphereMesh',{'radius':'.5','height':'1','radial_segments':'8','rings':'4'})
  else:mesh=self.resource('CylinderMesh',{'top_radius':'0' if kind=='cone' else ('.38' if kind=='tunic' else '.5'),'bottom_radius':'.5','height':'1','radial_segments':'7'})
  p={'position':vec(pos),'mesh':mesh,'material_override':mat}
  if name.startswith(('Crown','Trunk','Cliff')):p['visibility_range_begin']='3.5'
  if kind!='box':p['scale']=vec(size)
  if rot:p['rotation_degrees']=vec(rot)
  self.node(name,'MeshInstance3D',parent,p)
 def save(self,path):
  (R/path).write_text('[gd_scene load_steps=%d format=3]\n\n'% (len(self.res)+len(self.ext)+1)+'\n\n'.join(self.ext+self.res+self.nodes)+'\n')
  target=R/path;target.write_text(re.sub(r'(?<=[=(, ])\.(?=\d)', '0.', target.read_text()))
def vec(v):return 'Vector3(%s)'%', '.join(str(round(x,5)) for x in v)
def actor(dino=False,carno=False):
 s=Scene('Visual','res://scenes/visuals/actor_visual.gd'); mats={k:s.mat(v) for k,v in dict(amber='e7ae58',jade='69be9b',dark='183e3e',skin='cd9369',stone='b0c6bc',wood='634b3d',cream='fff2cd',red='c76c4c',purple='695778').items()}
 b=lambda n,k,p,z,m,pa='.',ro=None:s.shape(n,k,p,z,mats[m],pa,ro)
 if not dino:
  b('Tunic','tunic',(0,1.0,0),(.9,.82,.62),'amber');b('Belt','box',(0,.88,0),(.68,.13,.46),'wood');b('Buckle','box',(0,.88,-.25),(.13,.13,.05),'cream');b('Head','orb',(0,1.6,0),(.5,.55,.49),'skin');b('Hair','orb',(0,1.84,.055),(.55,.3,.54),'dark');b('Quiff','box',(-.08,1.88,-.09),(.4,.16,.28),'dark',ro=(0,0,-12));b('Scarf','box',(0,1.37,0),(.57,.14,.54),'jade');b('ScarfTail','box',(-.2,1.16,.28),(.21,.48,.075),'jade',ro=(-15,0,-10));b('Satchel','box',(.33,.92,.12),(.24,.3,.26),'wood');b('Clasp','orb',(.34,1.02,-.025),(.075,.075,.025),'cream')
  for x in [-1,1]:
   b('Eye'+str(x),'box',(x*.12,1.65,-.227),(.055,.045,.035),'dark')
   for limb,y,z in [('Leg',.55,0),('Arm',1.28,0)]:
    name=limb+('L' if x<0 else 'R');s.node(name,'Node3D','.',{'position':vec((x*(.19 if limb=='Leg' else .43),y,z))})
    b(name+'Part','box',(0,-.18,0),(.23,.42,.27) if limb=='Leg' else (.19,.4,.22),'dark' if limb=='Leg' else 'skin',name)
    if limb=='Leg':b(name+'Boot','box',(0,-.46,-.075),(.27,.2,.43),'wood',name)
  b('Haft','box',(0,-.22,-.28),(.065,.065,.68),'wood','ArmR',(-20,0,0));b('Hatchet','orb',(0,-.1,-.54),(.14,.4,.3),'stone','ArmR');b('Wrapping','box',(0,-.2,-.32),(.09,.09,.18),'cream','ArmR')
 else:
  tone='purple' if carno else 'red'
  b('Body','orb',(0,.93,.08),(.92,.86,1.34),tone);b('Belly','orb',(0,.83,-.28),(.66,.6,.8),'amber');b('Neck','orb',(0,1.29,-.45),(.5,.75,.57),tone);b('Head','orb',(0,1.63,-.72),(.72,.58,.92),tone);b('Muzzle','box',(0,1.55,-1.12),(.61,.25,.4),tone);b('Jaw','box',(0,1.41,-1.04),(.53,.09,.45),'cream');b('Tail','cone',(0,.91,1.05),(.58,1.65,.58),tone,ro=(80,0,0))
  b('Crest','cone',(0,1.98,-.6),(.31,.42,.16),'amber');b('Collar','box',(0,1.27,-.48),(.62,.18,.62),'jade');s.nodes[-1]+='\nvisible = false'
  for x in [-1,1]:
   b('Eye'+str(x),'orb',(x*.34,1.73,-.84),(.06,.17,.17),'cream');b('Pupil'+str(x),'orb',(x*.37,1.72,-.89),(.025,.1,.08),'dark')
   if carno:b('Horn'+str(x),'cone',(x*.27,1.96,-.7),(.19,.47,.19),'cream',ro=(0,0,-x*20))
   name='Leg'+('L' if x<0 else 'R');s.node(name,'Node3D','.',{'position':vec((x*.36,.67,.12))});b('Thigh'+str(x),'orb',(0,-.05,0),(.35,.64,.45),tone,name);b('Shin'+str(x),'box',(0,-.36,0),(.19,.3,.25),tone,name);b('Foot'+str(x),'box',(0,-.55,-.19),(.27,.19,.56),'dark',name)
   b('Arm'+str(x),'box',(x*.43,1.09,-.44),(.17,.25,.24),tone,ro=(-25,0,x*20))
   for a in range(2):b('Claw'+str(x)+str(a),'cone',(x*.36+(a-.5)*.11,.11,-.4),(.075,.18,.075),'cream',ro=(-90,0,0))
 s.save('scenes/visuals/'+('carno' if carno else 'dino' if dino else 'guardian')+'.tscn')
actor();actor(True);actor(True,True)
s=Scene('ArenaArt');m={k:s.mat(v, k=='light') for k,v in dict(grass='466b50',path='ad986c',stone='657e74',bark='60563f',leaf='285846',leaf2='40836b',leaf3='79975c',gold='d5a05d',jade='6ebd9a',dark='203d39',light='ffc776',sand='c5b184').items()}
def b(n,k,p,z,c,ro=None):s.shape(n,k,p,z,m[c],rot=ro)
b('Clearing','box',(0,-.49,0),(40,1,40),'grass');b('MainPath','box',(0,.02,0),(8,.045,33),'path');b('MeetingPath','box',(-5,.035,3),(12,.03,3),'path',(0,22,0))
for z in [-7]:
 b('Post','cylinder',(0,.08,z),(2.8,.08,2.8),'jade');b('PostInner','cylinder',(0,.13,z),(2.25,.08,2.25),'dark')
 s.node('PostLabel','Label3D','.',{'position':vec((0,.55,z)),'billboard':'1','text':'"POSTO DE DEFESA"','font_size':'40','pixel_size':'0.004','modulate':'Color(.95,.9,.7,1)'})
rng=random.Random(24)
for i in range(42):
 side=(-1 if i%2 else 1);x=side*rng.uniform(13,19);z=rng.uniform(-19,19);h=rng.uniform(2.5,5.8)
 b(f'Trunk{i}','cylinder',(x,h*.43,z),(.5,h*.9,.5),'bark')
 for j in range(2):b(f'Crown{i}_{j}','orb',(x,h*.76+j*.8,z),(3.2-j*.7,2.9-j*.5,3.2-j*.7),'leaf2' if i%3 else 'leaf')
for i in range(46):
 x=rng.choice([-1,1])*rng.uniform(6.5,19);z=rng.uniform(-19,19)
 if (x+10)**2+(z-5)**2<10:continue
 if i%3==0:b(f'Rock{i}','orb',(x,.38,z),(rng.uniform(.7,1.8),1.1,rng.uniform(.8,1.6)),'stone',(0,rng.uniform(0,180),8))
 else:
  for j in range(3):b(f'Fern{i}_{j}','cone',(x+j*.12,.3,z),(.24,.85,.42),'leaf3',(25,j*60,35))
for i in range(9):
 for side in [-1,1]:b(f'Cliff{i}_{side}','orb',(side*21,1.0,-19+i*5),(4,4,5),'stone')
for side in [-1,1]:
 b('ArchPillar'+str(side),'box',(side*3,2.1,16),(1.2,4.2,1.3),'stone',(0,side*7,side*-8))
 b('FirePost'+str(side),'cylinder',(side*3.3,1,-14.3),(.28,2,.28),'bark');b('Flame'+str(side),'cone',(side*3.3,2.2,-14.3),(.6,.9,.6),'light');s.node('Glow'+str(side),'OmniLight3D','.',{'position':vec((side*3,2.5,-14)),'light_color':'Color(1,.64,.27,1)','light_energy':'1.0','omni_range':'7'})
b('ArchTop','box',(0,4,16),(7.3,.9,1.3),'stone',(0,0,-5))
# Base geometry follows (0,-15); uncluttered approach from +Z.
b('RefugePlatform','cylinder',(0,.12,-15),(5,.25,5),'stone');b('RefugeRing','cylinder',(0,.3,-15),(3.8,.25,3.8),'sand');b('RefugeCore','cone',(0,1.2,-15),(1.1,1.9,1.1),'light',(0,0,180));b('RefugeCap','cone',(0,2.2,-15),(1.1,.75,1.1),'light')
for x in [-2,2]:
 b('BannerPole'+str(x),'cylinder',(x,1.6,-16),(.15,3.2,.15),'bark');b('Banner'+str(x),'box',(x+.35,2.65,-16),(.75,.9,.07),'jade');b('BannerEmblem'+str(x),'orb',(x+.35,2.65,-15.94),(.35,.35,.025),'gold')
# Visible perimeter + physics bounds; ornaments inside the arena do not block direct AI.
for i,(p,z) in enumerate([((20.2,1,0),(.4,2,40)),((-20.2,1,0),(.4,2,40)),((0,1,20.2),(40,2,.4)),((0,1,-20.2),(40,2,.4))]):
 s.node('Boundary'+str(i),'StaticBody3D','.',{'position':vec(p),'collision_layer':'1','collision_mask':'0'});shape=s.resource('BoxShape3D',{'size':vec(z)});s.node('Collider','CollisionShape3D','Boundary'+str(i),{'shape':shape})
b('BackdropGround','box',(0,-1.2,0),(110,1,110),'grass')
for i in range(22):
 a=i*math.tau/22;x=math.sin(a)*35;z=math.cos(a)*35
 b('Mountain'+str(i),'orb',(x,1,z),(rng.uniform(17,23),rng.uniform(10,16),rng.uniform(17,23)),'stone',(0,i*17,12))
s.save('scenes/visuals/arena_art.tscn')
# Integrate as visual children, preserve original physics nodes and scripts.
for scene,visual in [('player/player','guardian'),('enemies/wild_dino','dino'),('enemies/carnotauro','carno')]:
 p=R/('scenes/'+scene+'.tscn');txt=p.read_text()
 if 'ac1_visual' in txt:continue
 txt=txt.replace('[sub_resource',f'[ext_resource type="PackedScene" path="res://scenes/visuals/{visual}.tscn" id="ac1_visual"]\n\n[sub_resource',1);txt=txt.replace('[node name="MeshInstance3D" type="MeshInstance3D" parent="."]','[node name="MeshInstance3D" type="MeshInstance3D" parent="."]\nvisible = false').replace('[node name="NoseMarker" type="MeshInstance3D" parent="."]','[node name="NoseMarker" type="MeshInstance3D" parent="."]\nvisible = false');txt+='\n[node name="Visual" parent="." instance=ExtResource("ac1_visual")]\n';txt=txt.replace('spring_length = 4.0','spring_length = 6.0').replace('position = Vector3(0, 1.6, 0)','position = Vector3(0, 1.6, 0)\nrotation_degrees = Vector3(-18, 0, 0)');p.write_text(txt)
p=R/'scenes/world/prototype_area.tscn'
if 'ac1_arena' in p.read_text():raise SystemExit(0)
txt=p.read_text().replace('[sub_resource', '[ext_resource type="PackedScene" path="res://scenes/visuals/arena_art.tscn" id="ac1_arena"]\n\n[sub_resource',1).replace('[node name="TerritoryMarker" type="MeshInstance3D" parent="Territory"]','[node name="TerritoryMarker" type="MeshInstance3D" parent="Territory"]\nvisible = false').replace('[node name="MeshInstance3D" type="MeshInstance3D" parent="Ground"]','[node name="MeshInstance3D" type="MeshInstance3D" parent="Ground"]\nvisible = false').replace('Color(0.55, 0.72, 0.9, 1)','Color(0.58, 0.73, 0.69, 1)').replace('ambient_light_energy = 0.4','ambient_light_energy = 0.65').replace('shadow_enabled = true','shadow_enabled = true\nlight_color = Color(1, 0.91, 0.72, 1)\nlight_energy = 1.15');txt+='\n[node name="ArenaArt" parent="." instance=ExtResource("ac1_arena")]\n';p.write_text(txt)
