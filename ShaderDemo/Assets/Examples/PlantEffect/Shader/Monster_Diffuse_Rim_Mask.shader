
Shader "Actor/Character/Monster_Diffuse_Rim_Mask" 
{
    Properties 
    {                
        _Color ("Main Color", Color) = (1,1,1,1)                       
        _MainTex ("Base (RGB)", 2D) = "white" {}		
        _MaskTex ("Mask (RGB)", 2D) = "black" {}		
        _LightFactor("Light Factor",Float) = 0.3
		_HitFlg("Hit Flag",Range(0,1)) = 1	
        _MaskColor_1 ("mask 1 Color", Color) = (1,1,1,1)
		_MaskColor_2 ("mask 2 Color", Color) = (1,1,1,1)			
		_maskClrParam_1("mask 1 color param",Float) = 0
		_maskClrParam_2("mask 2 color param",Float) = 0	
		_RimColor ("Rim Color", Color) = (1, 1, 1, 1)
        _RimPower ("Rim Power", Range(0, 2)) = 0.25
        _RimParam ("Rim Param", Range(0, 2)) = 0.25
        _FakeDir("Fake Light Dir", Vector) = (1,2,1,0)

		_NosieTex("_NosieTex (RGB)", 2D) = "white" {}
		_EdgeTex("_EdgeTex (RGB)", 2D) = "white" {}
		_CutOut("CutOut",Range(0,1))=0
		_EdgeLength("Threshold",Range(0,1)) = 0
        _EdgeSpeed("EdgeSpeed",Range(1,3)) = 1

		_OuterColor("Outer Color", Color) = (1,1,1,1)
		[HDR]_InnerColor("Inner Color", Color) = (1,1,1,1)
		_InnerColorPower("Inner Color Power", Range(0.0,1.0)) = 1
		_OuterPower("Outer Power", Range(0.0,5.0)) = 5
		_AlphaPower("Alpha Outer Power", Range(0.0,8.0)) = 8
		_AllPower("All Power", Range(0.0, 10.0)) = 0

		[Space]
		_IsShowInnerGlow("IsShowInnerGlow(0 or 1)",Range(0,1)) = 0
		[HDR]_InnerGlow("InnerGlow",Color) = (1,1,1,1)
		_InnerGlowPower("InnerGlowPower",Range(0,3)) = 1
    }

    SubShader 
    {
        Tags{"RenderType"="Opaque" }    
		
		LOD 200

        Pass 
        {
            Name "FORWARD"
            Tags{ "LightMode" = "ForwardBase" "Queue"="AlphaTest+1" }            
            Cull back			

            CGPROGRAM
            #pragma vertex vert_surf
            #pragma fragment frag_surf
            #pragma exclude_renderers ps3 xbox360 flash xboxone ps4 psp2
            #pragma multi_compile_fwdbase
            #pragma multi_compile __ _MASKOFF
			#pragma multi_compile __ OEPN_DISSOLVE_MODEL
            #pragma skip_variants DYNAMICLIGHTMAP_ON DIRLIGHTMAP_COMBINED LIGHTMAP_ON LIGHTMAP_SHADOW_MIXING SHADOWS_SHADOWMASK SHADOWS_SCREEN
            #include "UnityCG.cginc"
            #include "Lighting.cginc"
            #include "AutoLight.cginc"


            sampler2D _MainTex;
			sampler2D _MaskTex;
			     
            fixed4 _Color;
            //fixed4 _ReflectColor;


			fixed _LightFactor;
			fixed _HitFlg;
			fixed4 _MaskColor_1;
			fixed4 _MaskColor_2;
			fixed _maskClrParam_1;
			fixed _maskClrParam_2;
			fixed4 _RimColor;
            fixed4 _FakeDir;
            fixed  _RimPower;
            fixed _RimParam;

			sampler2D _EdgeTex;
			sampler2D _NosieTex;
			fixed _CutOut;
			fixed _EdgeLength;
            fixed _EdgeSpeed; 

			float4 _OuterColor;
			float _OuterPower;
			float _AlphaPower;
			float _AlphaMin;
			float _InnerColorPower;
			float _AllPower;
			float4 _InnerColor;

			float _IsShowInnerGlow;
			float4 _InnerGlow;
			half _InnerGlowPower;

            struct appdata
            {
                float4 vertex : POSITION;               
                float3 normal : NORMAL;
                float4 texcoord : TEXCOORD0; 
                //float4 texcoord1 : TEXCOORD1;                                      
            }; 

            struct v2f_surf 
            {
                float4 pos : SV_POSITION;
                float2 pack0 : TEXCOORD0;                        
                half3 normal : TEXCOORD1;
                half3 vlight : TEXCOORD2;
                half3 worldPos : TEXCOORD3;
                LIGHTING_COORDS(5,6)
            };

            float4 _MainTex_ST;

            v2f_surf vert_surf (appdata v) 
            {
                v2f_surf o;                          
                o.pos = UnityObjectToClipPos (v.vertex);
                o.pack0.xy = TRANSFORM_TEX(v.texcoord, _MainTex);                
                float3 worldN = mul((float3x3)unity_ObjectToWorld, SCALED_NORMAL);  
                o.normal = worldN;                  
                float3 worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
                o.worldPos = worldPos;
                o.vlight = ShadeSH9(float4(worldN, 1.0));
                o.vlight += Shade4PointLights (
                    unity_4LightPosX0, unity_4LightPosY0, unity_4LightPosZ0,
                    unity_LightColor[0].rgb, unity_LightColor[1].rgb, unity_LightColor[2].rgb, unity_LightColor[3].rgb,
                    unity_4LightAtten0, worldPos, worldN );          
  
                TRANSFER_VERTEX_TO_FRAGMENT(o);
                return o;
            }
			
			//迭加个遮罩
			fixed4 mask_tex_color(fixed4 tex,fixed4 maskTex)
			{
				fixed4 c; 
				fixed3 t = fixed3(1.0,1.0,1.0);
				//fixed _maskClrParam_1 = 3.0 - _MaskColor_1.a;
				c.rgb = (t * (1-maskTex.rrr) + maskTex.rrr * _MaskColor_1.rgb * _maskClrParam_1) ;
				tex.rgb = c.rgb * tex.rgb;
				
				//_maskClrParam_1 = 3.0 - _MaskColor_2.a;
				c.rgb = (t * (1-maskTex.ggg) + maskTex.ggg * _MaskColor_2.rgb * _maskClrParam_2);			
				tex.rgb = c.rgb * tex.rgb;
				return tex;
			}
			
            fixed4 frag_surf (v2f_surf IN) : SV_Target 
            {  
                fixed4 tex = tex2D(_MainTex, IN.pack0.xy) * _Color;                

            #if _MASKOFF    
				fixed4 maskTex = tex2D(_MaskTex,IN.pack0.xy );
                tex = mask_tex_color(tex,maskTex);			
            #endif

                fixed atten = LIGHT_ATTENUATION(IN);
                fixed4 c;
                fixed diff = max (0, dot (IN.normal, _WorldSpaceLightPos0.xyz));
                diff = 0.5 * diff + 0.5;
                c.rgb = tex.rgb * diff * _LightColor0.rgb * atten * 0.5 + _LightFactor * tex.rgb * _LightColor0.rgb ;                
                c.rgb += tex.rgb * IN.vlight;  
				
				c.rgb = c.rgb * _HitFlg + 1 * (1 - _HitFlg);
				c.a = tex.a;

				half3 viewDir = normalize(_WorldSpaceCameraPos.xyz - IN.worldPos.xyz);
				
				float3 rim2 = saturate(dot(IN.normal, _FakeDir.xyz));              
                float rimPower = saturate(1.0 - pow(dot(IN.normal, viewDir), _RimPower));  
                c.rgb += rimPower * rim2 * _RimParam * _RimColor.rgb;

			#ifdef OEPN_DISSOLVE_MODEL
				fixed4 col = tex2D(_NosieTex, IN.pack0.xy);
				clip(col.g - _CutOut);
				fixed var1 = _CutOut > 0;
				fixed var2 = (col.g - _CutOut) < _EdgeLength;
				fixed4 edge = tex2D(_EdgeTex, IN.pack0.xy + _Time.x * _EdgeSpeed)*var1*var2;
				c.rgb = edge.rgb * 10 + c.rgb*(col.g - _CutOut > 0);
			#endif 

				half outer = 1.0 - saturate(dot(normalize(viewDir), IN.normal));
				fixed3 emission = _OuterColor.rgb * pow(outer, _OuterPower) * _AllPower + (_InnerColor.rgb * 2 * _InnerColorPower);
				half alphaPower = (pow(outer, _AlphaPower))*_AllPower;
				c.rgb += emission * alphaPower;

				float rim = (1 - saturate(dot(viewDir,IN.normal))) * _IsShowInnerGlow;
				c += _InnerGlow * pow(rim,_InnerGlowPower) *2;
                return fixed4(c.rgb, 1);
            }
            ENDCG
        }	

        UsePass "Legacy Shaders/VertexLit/SHADOWCASTER"
    }

    //FallBack "Diffuse"    
    //CustomEditor "ActorRimShaderGUI" 
}