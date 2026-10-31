"""Read collection OBJ positions, UVs, normals and triangulated faces. No third party packages."""


def read(p):
 v=[];uv=[];n=[];f=[]
 for s in p.read_text(encoding="utf-8").splitlines():
  a=s.split()
  if not a:continue
  if a[0]=='v':v.append(tuple(map(float,a[1:4])))
  elif a[0]=='vt':uv.append(tuple(map(float,a[1:3])))
  elif a[0]=='vn':n.append(tuple(map(float,a[1:4])))
  elif a[0]=='f':
   c=[tuple(int(z)-1 if z else -1 for z in x.split('/')) for x in a[1:]]
   f.extend((c[0],c[i],c[i+1]) for i in range(1,len(c)-1))
 return v,uv,n,f
