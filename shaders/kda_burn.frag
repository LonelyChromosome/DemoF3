#include <flutter/runtime_effect.glsl>
// Exact approved BPA burn fragment; only coordinate/sampler syntax is adapted.
out vec4 fragColor;
uniform vec2 uResolution;
uniform float uTime;
uniform float uDuration;
uniform vec2 uSize;
uniform sampler2D uNoise;

float n(vec2 p){return texture(uNoise,(mod(p,256.)+1.)/258.).r;}
float fb(vec2 p){return n(p)*.54+n(p*2.03+41.)*.27+n(p*4.09+17.)*.13+n(p*8.21)*.06;}
uniform sampler2D uArrival;
uniform sampler2D uTiming;
float decode(vec4 c){return (c.r*65280.+c.g*255.)*(2./65535.);}
float burnProgress(float phase){return decode(texture(uTiming,vec2((clamp(phase,0.,1.)*255.+.5)/256.,.5)));}
void main(){
 vec2 uv=FlutterFragCoord().xy/uSize; uv.y=1.-uv.y;
 // Isotropic turbulence, independent from screen aspect.
 vec2 p=uv;
 vec2 iso=uv*vec2(uResolution.x/uResolution.y,1.);
 float t=max(0.,uTime);
 float phase=clamp(t/uDuration,0.,1.);
 float grow=burnProgress(phase);
 vec2 curl=vec2(fb(iso*16.+29.),fb(iso*16.+93.))-.5;
 float arrival=decode(texture(uArrival,uv));
 float d=grow-arrival;
 float mask=smoothstep(-max(.002,1.8/uResolution.y),max(.002,1.8/uResolution.y),d);
 if(t<=.001){fragColor=vec4(0.);return;}
 if(phase>=1.){fragColor=vec4(0.,0.,0.,1.);return;}
 // Flowing hot gas: two travelling noise layers distort each other.
 vec2 flow=iso*70.+vec2(0.,-t*22.);
 float gas=fb(flow+curl*15.);
 float wisps=fb(iso*155.+vec2(t*9.,-t*38.)+gas*9.);
 float hot=fb(iso*240.+vec2(t*16.,-t*48.));
 float flutter=(gas-.46)*.014+(wisps-.5)*.008;
 float tip=d+flutter;
 float flame=exp(-abs(tip+.003)*165.)*smoothstep(.36,.72,gas)*1.15;
 flame+=exp(-abs(d+.001)*320.)*(.03+.7*wisps)*smoothstep(.37,.66,gas);
 flame*=smoothstep(-.075,-.017,d)*(1.-smoothstep(.012,.045,d));
 flame*=1.-smoothstep(.96,1.,phase);
 flame*=smoothstep(.30,.58,fb(iso*88.+vec2(t*3.,-t*8.)));
 float core=clamp(flame*.94,0.,1.);
 vec3 fire=vec3(1.,.17,.008)*min(flame*2.,1.);
 fire=mix(fire,vec3(1.,.67,.09),smoothstep(.24,.68,core));
 fire=mix(fire,vec3(1.,.97,.65),smoothstep(.86,1.,core));
 // Red embers stay just inside the consumed edge, then turn to black.
 float crack=smoothstep(.59,.78,fb(iso*300.+4.));
 float ember=exp(-max(d,0.)*65.)*mask*crack*(.5+.5*sin(t*19.+gas*32.));
 fire+=vec3(.55,.07,.003)*ember;
 // Soot rolls ahead of the flame, with a soft translucent outer boundary.
 float smokeBand=exp(-abs(d+.027)*26.)*(1.-mask);
 float smokeNoise=fb(iso*52.+curl*8.+vec2(t*2.,-t*10.));
 float smoke=smokeBand*smoothstep(.29,.72,smokeNoise)*.50;
 smoke*=smoothstep(.03,.19,phase)*(1.-smoothstep(.96,1.,phase));
 float glow=exp(-abs(d+.005)*95.)*.11*(.3+gas);
 glow*=1.-smoothstep(.96,1.,phase);
 // Sparse incandescent ash travels upward, rather than a screen of particles.
 vec2 sp=iso*vec2(100.,140.)+vec2(0.,-t*13.);
 vec2 cell=floor(sp);
 vec2 sub=fract(sp)-.5;
 float pick=n(cell*3.11+19.);
 float spark=(1.-smoothstep(.015,.11,length(sub*vec2(1.,.65))))*step(.976,pick);
 spark*=smoothstep(-.12,-.025,d)*(1.-smoothstep(-.025,.09,d));
 spark*=1.-smoothstep(.96,1.,phase);
 float fa=clamp(flame*1.35,0.,1.);
 float alpha=mask+(1.-mask)*clamp(smoke+fa+glow+spark,0.,1.);
 vec3 rgb=fire*fa+vec3(.08,.065,.055)*smoke*(1.-fa)+vec3(.6,.12,.006)*glow+vec3(1.,.56,.1)*spark;
 fragColor=vec4(clamp(rgb,0.,1.),alpha);
}

