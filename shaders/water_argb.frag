// ABI r3: 29 shared floats.
#include <flutter/runtime_effect.glsl>
#include "water_field.glsl"
out vec4 fragColor;
void main(){fragColor=vec4(rgbField(FlutterFragCoord().xy),1.);}
