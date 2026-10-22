import 'dart:math' as math;
import 'dart:typed_data';

/// Direct translation of buildBurnField in the user's approved BPA_BurnVFX.
/// Runs in compute(), keeping the 64-site distance field off the UI isolate.
Map<String, Uint8List> buildKdaBurnField(Map<String, num> input) {
  var state = input['seed']!.toInt() & 0xffffffff;
  final aspect = input['aspect']!.toDouble();
  double random() {
    state = (state * 1664525 + 1013904223) & 0xffffffff;
    return state / 4294967296;
  }
  final sites = <List<double>>[];
  for (var j = 0; j < 8; j++) {
    for (var i = 0; i < 8; i++) {
      final x = (i + .08 + random() * .84) / 8;
      final y = (j + .08 + random() * .84) / 8;
      final size = random();
      final scale = size < .14 ? 1.8 + random() * 1.5 : size < .59 ? 4 + random() * 3.5 : 8.5 + random() * 8;
      final angle = random() * math.pi * 2;
      sites.add([x,y,scale,.012+random()*.14,math.cos(angle),math.sin(angle),.6+random()*1.3,(random()*4).floorToDouble()]);
    }
  }
  final noise = Uint8List(65536);
  var ns = 134775813;
  for (var i = 0; i < noise.length; i++) {
    ns = (ns * 1664525 + 1013904223) & 0xffffffff;
    noise[i] = ns >> 24;
  }
  double sample(int x,int y) => noise[((y&255)<<8)+(x&255)]/255;
  double n(double x,double y) {
    x-=.5; y-=.5;
    final ix=x.floor(),iy=y.floor(),a=x-ix,b=y-iy;
    return (sample(ix,iy)*(1-a)+sample(ix+1,iy)*a)*(1-b)+(sample(ix,iy+1)*(1-a)+sample(ix+1,iy+1)*a)*b;
  }
  double fb(double x,double y) => n(x,y)*.54+n(x*2.03+41,y*2.03+41)*.27+n(x*4.09+17,y*4.09+17)*.13+n(x*8.21,y*8.21)*.06;
  final ox=random()*150,oy=random()*150;
  const width=128,height=224;
  final values=Float32List(width*height);
  for(var y=0;y<height;y++) {
    for(var x=0;x<width;x++) {
      final u=(x+.5)/width,v=(y+.5)/height,ix=u*aspect,iy=v;
      final px=u+(fb(ix*16+ox,iy*16+oy)-.5)*.075;
      final py=v+(fb(ix*16+ox+83,iy*16+oy+83)-.5)*.075;
      var nearest=2.0;
      for(final s in sites) {
        final dx=(px-s[0])*aspect,dy=py-s[1];
        var qx=(dx*s[4]-dy*s[5])*s[6]; final qy=dx*s[5]+dy*s[4];
        if(s[7]==1) { qx*=math.max(.4,1+qy*4.5); }
        else if(s[7]==2) { qx+=math.sin(qy*45)*.017; }
        else if(s[7]==3) { qx+=qy*qy*3.5; }
        var dist=math.sqrt(qx*qx+qy*qy);
        if(s[7]==2) { dist=math.min(dist,math.sqrt((qx-.012)*(qx-.012)+(qy+.016)*(qy+.016))*1.06); }
        nearest=math.min(nearest,dist*s[2]+s[3]);
      }
      values[y*width+x]=math.max(0.0,nearest+(fb(ix*34+ox,iy*34+oy)-.5)*.09+(fb(ix*115+oy,iy*115+ox)-.5)*.018);
    }
  }
  final sorted=values.toList()..sort();
  final q=List<double>.generate(33,(i)=>sorted[math.min(sorted.length-1,(i*(sorted.length-1)/32).round())]);
  q[0]=math.max(0.0,q[0]-.012); q[32]+=.008;
  final delta=List<double>.generate(32,(i)=>q[i+1]-q[i]);
  final m=Float64List(33);
  for(var i=1;i<32;i++) { m[i]=2*delta[i-1]*delta[i]/math.max(1e-12,delta[i-1]+delta[i]); }
  m[0]=math.min(3*delta[0],math.max(0.0,(3*delta[0]-delta[1])/2));
  m[32]=math.min(3*delta[31],math.max(0.0,(3*delta[31]-delta[30])/2));
  Uint8List pack(List<double> vals) {
    final out=Uint8List(vals.length*4);
    for(var i=0;i<vals.length;i++) {
      final a=((vals[i]/2).clamp(0,1)*65535).round();
      out[i*4]=a>>8;out[i*4+1]=a&255;out[i*4+3]=255;
    }
    return out;
  }
  final timing=Float32List(256);
  for(var j=0;j<256;j++) {
    final u=j/255*32,i=math.min(31,u.floor()),x=u-i;
    timing[j]=((2*q[i]-2*q[i+1]+m[i]+m[i+1])*x+(-3*q[i]+3*q[i+1]-2*m[i]-m[i+1]))*x*x+m[i]*x+q[i];
  }
  // A one-pixel wrapped border reproduces WebGL REPEAT with a clamp sampler.
  final padded=Uint8List(258*258*4);
  for(var y=0;y<258;y++) {
    for(var x=0;x<258;x++) {
      final value=noise[(((y-1)&255)<<8)+((x-1)&255)],i=(y*258+x)*4;
      padded[i]=value;padded[i+1]=value;padded[i+2]=value;padded[i+3]=255;
    }
  }
  return {'noise':padded,'arrival':pack(values),'timing':pack(timing)};
}
