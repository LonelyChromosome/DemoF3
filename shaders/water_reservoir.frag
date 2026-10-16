// r4: fluid geometry is reconstructed from PBF density on the CPU. This shader
// shades the actual free boundary; it never chooses a tilted half-plane.
#include <flutter/runtime_effect.glsl>
#include "water_field.glsl"
uniform vec3 uCoolant;
uniform float uRefraction;
uniform vec2 uFlow;
uniform float uEnergy;
uniform float uThickness;
out vec4 fragColor;
void main() {
 vec2 pos=FlutterFragCoord().xy,uv=pos/uSize;
 vec2 p=uv-uFlow;
 float circulation=sin(p.x*9.+sin(p.y*8.-uTime*.35))*sin(p.y*6.+uTime*.24);
 float vein=sin(p.x*17.+p.y*8.+circulation*2.4+uTime*.4);
 float caustic=pow(.5+.5*vein,16.);
 vec3 light=rgbField(pos);
 vec3 dye=mix(uCoolant,normalize(max(light,vec3(.0001)))*.72,.22);
 float transmission=.58+.15*circulation;
 vec3 water=dye*transmission+light*(.12+caustic*.16*uRefraction);
 float reflect=pow(.5+.5*sin(p.x*7.-p.y*4.+circulation*.8),24.);
 water+=vec3(.32,.29,.38)*reflect*uRefraction*(.35+min(uEnergy,1.)*.4);
 float depth=clamp(uThickness,0.,1.);
 float opacity=1.-exp(-2.8*depth);
 fragColor=vec4(water*.85*(.3+.7*sqrt(depth))*opacity,opacity);
}
