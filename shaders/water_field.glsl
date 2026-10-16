uniform vec2 uSize;uniform vec2 uOrigin;uniform vec2 uWorld;
uniform float uTime;uniform float uMode;uniform float uSpeed;uniform float uBrightness;uniform float uIntensity;uniform float uDirection;uniform float uWaveWidth;uniform float uBeamWidth;uniform float uColorCount;
uniform vec3 uColor0;uniform vec3 uColor1;uniform vec3 uColor2;uniform vec3 uColor3;uniform float uFeedback;uniform float uWarning;
vec3 paletteColor(float i){if(i<.5)return uColor0;if(i<1.5)return uColor1;if(i<2.5)return uColor2;return uColor3;}
vec3 palette(float x){float v=fract(x)*uColorCount;return mix(paletteColor(floor(v)),paletteColor(mod(floor(v)+1.,uColorCount)),fract(v));}
vec3 spectrum(float h){return clamp(abs(fract(h+vec3(0.,.6666667,.3333333))*6.-3.)-1.,0.,1.)*.8+.2;}
vec3 rgbField(vec2 point){vec2 uv=(point+uOrigin)/uWorld;float a=uDirection*.01745329252;float p=dot(uv-.5,vec2(cos(a),sin(a)))+.5;float t=uTime*(.04+uSpeed*.7);float light=1.;vec3 c=uColor0;
if(uMode>.5&&uMode<1.5)c=spectrum(p-t);
if(uMode>1.5&&uMode<2.5)c=palette(p/uWaveWidth-t);
if(uMode>2.5&&uMode<3.5){float d=(fract(p-t)-.5)/uBeamWidth;light=.06+.94*exp(-d*d);}
if(uMode>3.5&&uMode<4.5){float f=clamp(.5+.25*sin(uv.x*8.+t*7.)+.25*sin(uv.y*13.-t*11.+uv.x*4.),0.,1.);c=mix(vec3(.72549,.11765,.03529),vec3(1.,.78431,.35686),f);light=.35+.65*f;}
if(uMode>4.5&&uMode<5.5)light=.18+.82*(.5+.5*sin(t*6.2831853));
if(uMode>5.5&&uMode<6.5)light=.08+.92*pow(clamp(.5+.5*cos(t*6.2831853),0.,1.),9.);
if(uMode>6.5&&uMode<7.5)light=.06+.94*exp(-fract(p-t)/uBeamWidth);
if(uMode>7.5&&uMode<8.5)c=palette(p*.65);
if(uMode>8.5&&uMode<9.5)c=palette(p-t);
if(uMode>9.5)c=spectrum(dot(uv,vec2(3.*cos(a)+2.*sin(a),-3.*sin(a)+2.*cos(a)))-t);
c=mix(c,vec3(1.,.18,.055),uWarning);return c*uBrightness*(1.-uIntensity+uIntensity*light)*(1.+.25*uFeedback);}
