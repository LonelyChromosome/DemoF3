from pathlib import Path
import struct
import numpy as np
import cv2
from PIL import Image
root=Path("findbike-build/app/src/main/assets")
im=np.asarray(Image.open(root/"map_hires.webp").resize((1448,1086),Image.Resampling.LANCZOS).convert("RGB")).astype(np.int16)
r,g,b=im.transpose(2,0,1)
core=(r>=200)&(r<=236)&(g-r>=-1)&(g-r<=4)&(b-r>=2)&(b-r<=12)
mask=core.astype("uint8")*255
count, labels, stats, _=cv2.connectedComponentsWithStats(mask,8)
keep=np.zeros_like(mask)
for i in range(1,count):
    if stats[i,cv2.CC_STAT_AREA]>=17:keep[labels==i]=255
keep=cv2.morphologyEx(keep,cv2.MORPH_CLOSE,cv2.getStructuringElement(cv2.MORPH_ELLIPSE,(7,7)))
keep=cv2.dilate(keep,cv2.getStructuringElement(cv2.MORPH_ELLIPSE,(7,7)))
W,H=362,272
arr=np.pad(keep,((0,H*4-1086),(0,W*4-1448)))
grid=(arr.reshape(H,4,W,4).max(axis=(1,3))>0).ravel()
bits=bytearray((len(grid)+7)//8)
for i,value in enumerate(grid):
    if value:bits[i//8]|=1<<(i%8)
(root/"blocked_grey.bin").write_bytes(struct.pack(">HH",W,H)+bits)
print("Blocked grey mask:",int(grid.sum()),"cells of",len(grid))
