// (i) Special thanks to bambosan
#ifndef CLOUD_NOISE_TEX
    #define CLOUD_NOISE_TEX cloudNoise
    uniform mediump sampler2D cloudNoise;
#endif
#ifndef CLOUD_AMBIENT_LUMA_LOCK
#define CLOUD_AMBIENT_LUMA_LOCK 1
#endif
#ifndef CLOUD_USE_GATHER
#define CLOUD_USE_GATHER 1
#endif
#ifndef CLOUD_MAX_ITER
#define CLOUD_MAX_ITER 640
#endif
#define CLD_HP highp
#define CLD_MP mediump

const CLD_HP float CLOUD_HEIGHT=200.0;
const CLD_HP float CLOUD_THICKNESS=200.0;
const CLD_HP float CLOUD_MAX_Y=500.0;
const CLD_HP float CLOUD_EPS=1e-6;
const CLD_MP float CLOUD_EPS_MP=1e-4;

const CLD_HP float CLOUD_STEP=10.0;
const int      CLOUD_SKIP_FACTOR=1;
const CLD_MP float CLOUD_SKIP_MARGIN=0.07;
const int      CLOUD_SKIP_ZERO_RUN=3;
const CLD_HP float CLOUD_TRANS_CUT=0.005;
const CLD_HP float CLOUD_LIGHT_MIN_WEIGHT=1e-3;
const CLD_MP float CLOUD_LIGHT_LOW_WEIGHT=0.01;
const CLD_HP float CLOUD_STEP_GROWTH_START=8000.0;
const CLD_HP float CLOUD_STEP_GROWTH_RATE=1.0/4000.0;
const CLD_MP float CLOUD_DENSE_MULT=3.0;
const CLD_MP float CLOUD_DENSE_LO=0.04;
const CLD_MP float CLOUD_DENSE_HI=0.10;
const CLD_HP float CLOUD_MAX_DIST=14000.0;
const CLD_HP float CLOUD_FADE_START=4000.0;
const CLD_HP float CLOUD_FADE_END=12000.0;
const CLD_MP float CLOUD_FADE_MAX=1.0;
const CLD_MP float CLOUD_RADIANCE_TRIM=1.0163;

const CLD_MP float CLOUD_DENSITY_BRIDGE=1.75;
const CLD_MP float CLOUD_DEPTH_SCALE=0.04;
const CLD_MP float CLOUD_MULTIPLE_SCALE=1.30;
const CLD_MP float CLOUD_IN_SCATTER_STRENGTH=0.07;
const CLD_MP float CLOUD_AMBIENT_SCALE=0.50;
const CLD_MP float CLOUD_AMBIENT_OCCLUSION_SCALE=0.010;
const CLD_MP float CLOUD_SHADOW_POWER=3.0;
const CLD_MP float CLOUD_SILVER_GAIN=0.50;
const CLD_MP float CLOUD_SKY_BOUNCE=0.50;
const CLD_MP float CLOUD_AMBIENT_FLOOR=0.14;
const CLD_MP float CLOUD_POWDER_GAIN=0.45;

CLD_HP float gCloudTime;

CLD_MP vec4 cloudTexelsR(int ix,int iy,int layer){
    int oy=layer*256;
#if CLOUD_USE_GATHER
    if(ix<255 && iy<255){
        CLD_HP vec2 uv=vec2(float(ix+1),float(iy+1+oy))*vec2(1.0/256.0,1.0/1024.0);
        return textureGather(CLOUD_NOISE_TEX,uv,0).wzxy;
    }
#endif
    int x1=(ix+1)&255, y1=(iy+1)&255;
    return vec4(texelFetch(CLOUD_NOISE_TEX,ivec2(ix,iy+oy),0).r,texelFetch(CLOUD_NOISE_TEX,ivec2(x1,iy+oy),0).r,
                texelFetch(CLOUD_NOISE_TEX,ivec2(ix,y1+oy),0).r,texelFetch(CLOUD_NOISE_TEX,ivec2(x1,y1+oy),0).r);
}
void cloudTexelsRG(int ix,int iy,int layer,out CLD_MP vec4 R,out CLD_MP vec4 G){
    int oy=layer*256;
#if CLOUD_USE_GATHER
    if(ix<255 && iy<255){
        CLD_HP vec2 uv=vec2(float(ix+1),float(iy+1+oy))*vec2(1.0/256.0,1.0/1024.0);
        R=textureGather(CLOUD_NOISE_TEX,uv,0).wzxy; G=textureGather(CLOUD_NOISE_TEX,uv,1).wzxy; return;
    }
#endif
    int x1=(ix+1)&255, y1=(iy+1)&255;
    CLD_MP vec4 a=texelFetch(CLOUD_NOISE_TEX,ivec2(ix,iy+oy),0), b=texelFetch(CLOUD_NOISE_TEX,ivec2(x1,iy+oy),0);
    CLD_MP vec4 c=texelFetch(CLOUD_NOISE_TEX,ivec2(ix,y1+oy),0), d=texelFetch(CLOUD_NOISE_TEX,ivec2(x1,y1+oy),0);
    R=vec4(a.r,b.r,c.r,d.r); G=vec4(a.g,b.g,c.g,d.g);
}

CLD_MP float cloudValueNoise(CLD_HP vec2 uv){
    uv-=0.5; CLD_HP vec2 iu=floor(uv); CLD_HP vec2 f=uv-iu;
    CLD_MP vec2 s=f*f*(3.0-2.0*f);
    CLD_MP vec4 p=cloudTexelsR(int(iu.x)&255,int(iu.y)&255,0);
    return mix(mix(p.x,p.y,s.x),mix(p.z,p.w,s.x),s.y);
}
CLD_MP float cloudWorley(CLD_HP vec3 p){
    CLD_HP float x=mod(p.x,32.0), y=mod(p.y,32.0), z=mod(p.z,36.0);
    CLD_HP float iz=floor(z); CLD_MP float fz=z-iz;
    CLD_HP float col=mod(iz,6.0)*34.0, row=floor(iz/6.0)*34.0;
    CLD_HP float u=mod(x+col+1.0,256.0), v=mod(y-34.0-row+1.0,256.0);
    CLD_HP float fu0=floor(u), fv0=floor(v);
    CLD_MP vec2 f=vec2(u-fu0,v-fv0);
    CLD_MP vec4 R,G; cloudTexelsRG(int(fu0)&255,int(fv0)&255,3,R,G);
    CLD_MP float a=mix(mix(R.x,R.y,f.x),mix(R.z,R.w,f.x),f.y);
    CLD_MP float b=mix(mix(G.x,G.y,f.x),mix(G.z,G.w,f.x),f.y);
    return mix(a,b,fz);
}

CLD_MP float cloudBase2D(CLD_HP vec2 xz){
    CLD_HP float bx=xz.x*0.003, bz=(xz.y+gCloudTime)*0.003;
    CLD_MP float b=cloudValueNoise(vec2(bx,bz))+0.5*cloudValueNoise(vec2(bx*2.0,bz*2.0))
              +0.25*cloudValueNoise(vec2(bx*4.0,bz*4.0))+0.125*cloudValueNoise(vec2(bx*8.0,bz*8.0));
    return clamp(b*0.533333-0.25,0.0,1.0);
}
CLD_MP float cloudHeight01(CLD_HP float y){ return clamp((y-CLOUD_HEIGHT)*(1.0/CLOUD_THICKNESS),0.0,1.0); }
CLD_MP float cloudLinestep(CLD_MP float a,CLD_MP float b,CLD_MP float x){ return clamp((x-a)/max(b-a,CLOUD_EPS_MP),0.0,1.0); }
CLD_MP float cloudRamp(CLD_MP float b,CLD_MP float h){
    CLD_MP float h2=h*h, h4=h2*h2, h8=h4*h4;
    b=cloudLinestep(h8,1.0,b);
    return cloudLinestep(exp(-h*25.0),1.0,b);
}
CLD_MP float cloudDensityFromBase(CLD_MP float b,CLD_HP vec3 p,out CLD_MP float profile){
    CLD_MP float h=cloudHeight01(p.y); CLD_MP float r=cloudRamp(b,h); profile=r;
    if(r<=0.0) return 0.0;
    CLD_MP float w=cloudWorley(vec3(p.x*0.15,p.y*0.15,p.z*0.15+gCloudTime*0.05));
    return cloudLinestep(w*h,1.0,r);
}
CLD_MP float cloudDensityFull(CLD_HP vec3 p){ CLD_MP float pr; return cloudDensityFromBase(cloudBase2D(p.xz),p,pr); }

CLD_HP float cloudHG(CLD_HP float c,CLD_HP float g){
    CLD_HP float den=max(1.0+g*g-2.0*g*c,CLOUD_EPS);
    return (1.0-g*g)/(12.566370614*den*sqrt(den));
}
CLD_MP float cloudAmbientLumaRatio(CLD_MP float ly){
    CLD_MP float y=clamp(ly,0.0,1.0); return ((-0.72240529*y+1.33712416)*y-0.75563019)*y+0.88994799;
}

#ifdef MIRAI_SKY
vec3 miraiSkyAmbient(){
    vec3 acc=MIRAI_SKY(vec3(0.0,1.0,0.0))*1.0; float ws=1.0;
    for(int i=0;i<6;i++){ float az=6.283185307*float(i)/6.0; acc+=MIRAI_SKY(vec3(cos(az)*0.8660254,0.5,sin(az)*0.8660254))*0.5; ws+=0.5; }
    acc+=MIRAI_SKY(vec3(0.9836666,0.18,0.0))*0.18; acc+=MIRAI_SKY(vec3(-0.9836666,0.18,0.0))*0.18; ws+=0.36;
    return acc/ws;
}
#endif

CLD_HP vec3 miraiCloudCompositeCut(CLD_HP vec3 cam,CLD_HP vec3 rd,CLD_HP vec3 ld,CLD_MP vec3 sunCol,CLD_MP vec3 skyAmbientRaw,CLD_HP vec3 bg,
                            CLD_HP float timeX,CLD_HP float tCut,out CLD_HP float transmittance,out CLD_HP vec3 radiance)
{
    gCloudTime=timeX;
    CLD_MP vec3 ambientCol=skyAmbientRaw;
#if CLOUD_AMBIENT_LUMA_LOCK
    ambientCol*=cloudAmbientLumaRatio(ld.y);
#endif
    CLD_MP vec3 shadowLightCol=(1.0-CLOUD_SKY_BOUNCE)*sunCol+CLOUD_SKY_BOUNCE*ambientCol;
    ambientCol=max(ambientCol,vec3(0.0));
    CLD_MP vec3 inscCol=0.55*shadowLightCol+0.45*ambientCol;

    CLD_HP float dy=abs(rd.y)<1e-7 ? (rd.y>=0.0?1e-7:-1e-7) : rd.y;
    CLD_HP float tb=(CLOUD_HEIGHT-cam.y)/dy, tt=(CLOUD_MAX_Y-cam.y)/dy;
    bool above=cam.y>CLOUD_MAX_Y, below=cam.y<CLOUD_HEIGHT;
    CLD_HP float tmin=above?tt:(below?tb:0.0);
    CLD_HP float tmax=above?tb:(below?tt:(dy>0.0?tt:tb));
    bool valid=above?(dy<0.0):(below?(dy>0.0):(tmax>0.0));
    tmax=min(tmax,min(CLOUD_MAX_DIST,tCut)); valid=valid && tmax>=tmin;

    CLD_HP float trans=1.0; CLD_HP vec3 rad=vec3(0.0); CLD_HP float wsumT=0.0, wsum=0.0;
    CLD_HP float t=max(tmin,0.0);
    bool fine=(CLOUD_SKIP_FACTOR<=1); int zeroRun=0; CLD_MP float prevD=0.0;
    CLD_MP float cosv=dot(rd,ld);
    CLD_MP float basePhase=0.80*cloudHG(cosv,0.70)+0.20*cloudHG(cosv,-0.12);
    CLD_MP float silverPhase=CLOUD_SILVER_GAIN*cloudHG(cosv,0.965);
    CLD_MP float silverCos=smoothstep(0.20,0.92,cosv);
    CLD_MP float silverGain=max(silverPhase-basePhase,0.0);
    CLD_MP float viewMix=smoothstep(0.10,0.92,cosv);
    CLD_MP float sunFacing=smoothstep(-0.10,0.90,cosv);
    CLD_MP float hgBack=cloudHG(cosv,-0.16), hgIso=cloudHG(cosv,0.0);
    CLD_HP float invLdY=1.0/max(ld.y,0.05);

    if(valid){
    for(int it=0; it<CLOUD_MAX_ITER; it++){
        if(!(t<tmax && trans>CLOUD_TRANS_CUT)) break;
        CLD_HP float stepf=CLOUD_STEP*(1.0+CLOUD_STEP_GROWTH_RATE*max(t-CLOUD_STEP_GROWTH_START,0.0));

        if(!fine){
            CLD_HP float L=float(CLOUD_SKIP_FACTOR)*stepf, tc=t+0.5*L;
            CLD_MP float b=cloudBase2D((cam+rd*tc).xz);
            CLD_HP float y0=cam.y+rd.y*t, y1=cam.y+rd.y*(t+L);
            CLD_MP float bm=clamp(b+CLOUD_SKIP_MARGIN,0.0,1.0);
            if(cloudRamp(bm,cloudHeight01(y0))>0.0 || cloudRamp(bm,cloudHeight01(y1))>0.0 || cloudRamp(bm,cloudHeight01(0.5*(y0+y1)))>0.0){ fine=true; zeroRun=0; }
            else { t+=L; continue; }
        }

        CLD_HP float sf=stepf*(1.0+(CLOUD_DENSE_MULT-1.0)*smoothstep(CLOUD_DENSE_LO,CLOUD_DENSE_HI,prevD));
        sf=min(sf,max(tmax-t,1e-3));
        CLD_HP vec3 pp=cam+rd*(t+0.5*sf);
        CLD_MP float bb=cloudBase2D(pp.xz);
        CLD_MP float dp; CLD_MP float dd=cloudDensityFromBase(bb,pp,dp);
        bool use=dd>1e-8; prevD=dd;
        zeroRun=use?0:zeroRun+1;
        if(CLOUD_SKIP_FACTOR>1 && zeroRun>=CLOUD_SKIP_ZERO_RUN){ fine=false; zeroRun=0; prevD=0.0; }

        if(use){
            CLD_MP float stT=exp(-dd*sf);
            CLD_HP float weight=trans*(1.0-stT);
            if(weight>=CLOUD_LIGHT_MIN_WEIGHT){
                CLD_MP float h=cloudHeight01(pp.y);
                CLD_HP float lightPath=min(max((CLOUD_MAX_Y-pp.y)*invLdY,0.0),800.0);
                int ns=(weight>=CLOUD_LIGHT_LOW_WEIGHT)?8:4;
                CLD_MP float odSum=0.0;
                for(int i=0;i<8;i++){
                    if(i>=ns) break;
                    CLD_HP float u=(float(i)+0.5)/float(ns);
                    odSum+=cloudDensityFull(pp+ld*(lightPath*u));
                }
                CLD_MP float od=odSum*(lightPath/float(ns));
                CLD_MP float d=od*CLOUD_DENSITY_BRIDGE*CLOUD_DEPTH_SCALE;
                CLD_MP float T=exp(-d);

                CLD_MP float silverMask=smoothstep(0.30,0.82,T)*silverCos;
                CLD_MP float primary=basePhase+silverMask*silverGain;
                CLD_MP float powder=1.0-exp(-dd*30.0);
                CLD_MP float p2=powder*powder, powderTerm=p2*p2*powder*5.0;
                CLD_MP float powderFactor=viewMix+(1.0-viewMix)*(1.0+CLOUD_POWDER_GAIN*(powderTerm-1.0));
                primary*=max(powderFactor,0.35);
                CLD_MP float Tsh=T*T*T;
                CLD_MP vec3 direct=(Tsh*primary)*sunCol;

                CLD_MP float profile=clamp(dp*CLOUD_DENSITY_BRIDGE,0.0,1.0);
                CLD_MP float msAtten=0.26+(0.055-0.26)*profile;
                msAtten=0.26+(msAtten-0.26)*sunFacing;
                CLD_MP float multProb=profile*exp(-d*msAtten);
                multProb*=0.62+0.38*smoothstep(0.05,0.30,h);
                CLD_MP float secondary=(1.0-profile)*hgBack+profile*hgIso;
                CLD_MP vec3 multiple=(multProb*secondary*CLOUD_MULTIPLE_SCALE)*shadowLightCol;

                CLD_MP float depthExp=0.5+1.5*smoothstep(0.30,0.85,h);
                CLD_MP float depthProb=0.05+pow(max(profile,0.0),depthExp);
                CLD_MP float vertProb=pow(clamp((h-0.07)/0.07,0.0,1.0)*0.9+0.1,0.8);
                CLD_MP vec3 inscatter=(depthProb*vertProb*Tsh*secondary*CLOUD_IN_SCATTER_STRENGTH)*inscCol;

                CLD_MP float ambOd=0.0;
                for(int k=0;k<4;k++){
                    CLD_HP float ay=pp.y+35.0+70.0*float(k);
                    if(ay>CLOUD_MAX_Y) break;
                    CLD_MP float pr; ambOd+=cloudDensityFromBase(bb,vec3(pp.x,ay,pp.z),pr)*70.0;
                }
                CLD_MP float ambProb=(CLOUD_AMBIENT_FLOOR+(1.0-CLOUD_AMBIENT_FLOOR)*sqrt(max(1.0-profile,0.0)))*exp(-ambOd*CLOUD_AMBIENT_OCCLUSION_SCALE);
                CLD_MP vec3 ambient=(ambProb*CLOUD_AMBIENT_SCALE)*ambientCol;

                CLD_MP vec3 Lrad=direct+multiple+inscatter+ambient;
                rad+=weight*Lrad;
                wsumT+=weight*(t+0.5*stepf); wsum+=weight;
            }
            trans*=stT;
        }
        t+=sf;
    }
    }
    radiance=rad*CLOUD_RADIANCE_TRIM; transmittance=trans;
    CLD_HP vec3 color=trans*bg+radiance;
    CLD_HP float fade=CLOUD_FADE_MAX*smoothstep(CLOUD_FADE_START,CLOUD_FADE_END,wsumT/max(wsum,CLOUD_EPS))*(wsum>0.0?1.0:0.0);
    return bg+(color-bg)*(1.0-fade);
}

CLD_HP vec3 miraiCloudComposite(CLD_HP vec3 cam,CLD_HP vec3 rd,CLD_HP vec3 ld,CLD_MP vec3 sunCol,CLD_MP vec3 skyAmbientRaw,CLD_HP vec3 bg,
                            CLD_HP float timeX,out CLD_HP float transmittance,out CLD_HP vec3 radiance)
{
    return miraiCloudCompositeCut(cam,rd,ld,sunCol,skyAmbientRaw,bg,timeX,CLOUD_MAX_DIST,transmittance,radiance);
}
