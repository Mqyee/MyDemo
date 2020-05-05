Shader "Actor/Character/Hair Two Pass Kajiya1"
{
	Properties
	{
		_Color("Main Color", Color) = (1,1,1,1)
		_MainTex("Albedo", 2D) = "white" {}
		_MetallicGlossMap("R(Anisotropy)G(AO)B(Smoothness)", 2D) = "white" {}
		_SpecularMultiplier("Specular Multiplier", float) = 128
		_PrimaryShift("Specular Primary Shift", float) = 0.02
		_EnvBoost1("Specular Primary Boost", Range(0.5, 2)) = 1.42
		_SpecularMultiplier2("Secondary Specular Multiplier", float) = 128
		_SecondaryShift("Specular Secondary Shift", float) = -0.6
		_EnvBoost2("Specular Secondary Boost", Range(0.5, 2)) = 1.34
		[Gamma]_Metallic("Anisotropy", Range(0.0, 1.0)) = 1.0
		_GlossMapScale("Smoothness", Range(0.0, 1.0)) = 1.0
		_OcclusionStrength("Occlusion Strength", Range(0.0, 1.0)) = 1.0
		_CutOff("Cut Off", Range(0.0, 1.0)) = 0.02
		[HDR]_SubsurfaceColor("SubsurfaceColor", Color) = (1,1,1,1)

		_OuterColor("Outer Color", Color) = (1,1,1,1)
		[HDR]_InnerColor("Inner Color", Color) = (1,1,1,1)
		_InnerColorPower("Inner Color Power", Range(0.0,1.0)) = 1
		_OuterPower("Outer Power", Range(0.0,5.0)) = 5
		_AlphaPower("Alpha Outer Power", Range(0.0,8.0)) = 8
		_AllPower("All Power", Range(0.0, 10.0)) = 0
	}


	SubShader
	{
		//为了写入深度以不被景深效果模糊前移渲染队列（Queue在2500之后的都不进行深度写入）
		Tags { "RenderType"="Opaque" "Queue" = "AlphaTest+48" }
		LOD 200
	
		Pass
		{
			Name "FORWARD" 
			Tags { "LightMode" = "ForwardBase" }
			Blend SrcAlpha OneMinusSrcAlpha

			CGPROGRAM
			//#pragma target 2.0						

			//#pragma multi_compile __ UNITY_COLORSPACE_GAMMA

			//#pragma multi_compile __ _EMISSION					
			#pragma multi_compile_fwdbase
			//#pragma multi_compile_fog			
			#pragma multi_compile __ XCHAR_SHADOW_ON	

			#pragma exclude_renderers ps3 xbox360 flash xboxone ps4 psp2		
			#pragma skip_variants DYNAMICLIGHTMAP_ON DIRLIGHTMAP_COMBINED LIGHTMAP_ON LIGHTMAP_SHADOW_MIXING FOG_EXP FOG_EXP2 SHADOWS_SHADOWMASK
			
			#pragma vertex vertBase
			#pragma fragment fragBase						
			
			#include "UnityCG.cginc"
			#include "AutoLight.cginc"							
			#include "UnityStandardUtils.cginc"
			#include "UnityStandardBRDF.cginc"	
			#include "Common.cginc"	

			half4       _Color;			
			sampler2D   _MainTex;
			float4      _MainTex_ST;
			

			sampler2D   _MetallicGlossMap;								
			half 		_Metallic;
			half        _GlossMapScale;					
			half        _OcclusionStrength;	

			sampler2D	_EmissionMap;
			half4  		_EmissionColor;
			float		_CutOff;

			float _EnvBoost1;
			float _EnvBoost2;

			float _SpecularMultiplier;
			float _SpecularMultiplier2;
			float  _PrimaryShift;
			float _SecondaryShift;

			half4 _OuterColor;
			half _OuterPower;
			half _AlphaPower;
			half _AlphaMin;
			half _InnerColorPower;
			half _AllPower;
			half4 _InnerColor;

			struct VertexInput
			{
			    float4 vertex   : POSITION;
			    half3 normal    : NORMAL;
			    float2 uv0      : TEXCOORD0;	
			    half4 tangent   : TANGENT;
			};

			struct VertexOutput
			{
			    float4 pos : SV_POSITION;
			    float2 uv : TEXCOORD0;
			  //  half3 eyeVec : TEXCOORD1;
			    TBN_WORLD_COORDS(2, 3, 4)				// [3x3:tangentToWorld | 1x3:viewDirForParallax or worldPos]
			    half3 ambient : TEXCOORD5;    			// SH or Lightmap UV
#if defined (XCHAR_SHADOW_ON)
				float4 shadowPos	: TEXCOORD6;
#else
				UNITY_SHADOW_COORDS(6)
#endif
			};

			//顶点着色
    		VertexOutput vertBase (VertexInput v) 
    		{    			
			    VertexOutput o = (VertexOutput)0;			    		    			   			    
			    float4 posWorld = mul(unity_ObjectToWorld, v.vertex);
							    
			    o.pos = mul(UNITY_MATRIX_VP, posWorld);
			    o.uv = TRANSFORM_TEX(v.uv0, _MainTex);
			    //o.eyeVec = posWorld.xyz - _WorldSpaceCameraPos;
			    float3 normalWorld = UnityObjectToWorldNormal(v.normal);
				TRANSFER_WORLD_POS(o, posWorld);	

		        float3 tangentWorld = UnityObjectToWorldDir(v.tangent.xyz);

		        float sign = v.tangent.w * unity_WorldTransformParams.w;
		        float3 binormal = cross(normalWorld, tangentWorld) * sign;

				///*			tangentWorld = cross(binormal, normalWorld);

				//			normalWorld = cross(tangentWorld, binormal);*/

		        TRANSFER_TBN_ROTATION(o, tangentWorld, binormal, normalWorld);

			    half3 ambient = 0;

		    #ifdef UNITY_SHOULD_SAMPLE_SH
		        #ifdef VERTEXLIGHT_ON			            
		            ambient = Shade4PointLights (unity_4LightPosX0, unity_4LightPosY0, unity_4LightPosZ0,
		                unity_LightColor[0].rgb, unity_LightColor[1].rgb, unity_LightColor[2].rgb, unity_LightColor[3].rgb,
		                unity_4LightAtten0, posWorld, normalWorld);
		        #endif

		        ambient = ShadeSHPerVertex (normalWorld, ambient);
			#endif
			    o.ambient = ambient;
			    

#if defined (XCHAR_SHADOW_ON)
				o.shadowPos = mul(_Global_ShadowMatrix, posWorld);
#else
				TRANSFER_SHADOW(o);
#endif
			    return o;    			
    		}		

			half4  		_SubsurfaceColor;


	
			// Based on Minimalist CookTorrance BRDF
// Implementation is slightly different from original derivation: http://www.thetenthplanet.de/archives/255
//
// * NDF (depending on UNITY_BRDF_GGX):
//  a) BlinnPhong
//  b) [Modified] GGX
// * Modified Kelemen and Szirmay-​Kalos for Visibility term
// * Fresnel approximated with 1/LdotH
			half4 XBRDF2_Unity_PBS(half3 diffColor, half3 specColor, half oneMinusReflectivity, half rough,
				float3 normal, float3 tangent, float3 bitangent, float3 viewDir,
				UnityLight light, UnityIndirect gi, float anisotropy)
			{
				float3 h = float3(light.dir) + viewDir; // Unnormalized half-way vector  
				float3 halfDir = Unity_SafeNormalize(h);

				half onl = dot(normal, light.dir);
				half nl = saturate(onl);
				float nh = saturate(dot(normal, halfDir));
				half nv = saturate(dot(normal, viewDir));
				float lh = saturate(dot(light.dir, halfDir));

				// Specular term
				half perceptualRoughness = (rough);
				half roughness = PerceptualRoughnessToRoughness(perceptualRoughness);

				half shiftTex = anisotropy;
				half3 T = bitangent;

				half3 t1 = ShiftTangent(T, normal, _PrimaryShift + shiftTex);
				half3 t2 = ShiftTangent(T, normal, _SecondaryShift + shiftTex);

				//Specular term
				float specularTerm;
				specularTerm = _EnvBoost1* StrandSpecular(t1, viewDir, light.dir, _SpecularMultiplier)* lerp(1, nl, _Color.rgb) ;
				specularTerm += _EnvBoost2* StrandSpecularS(t2, viewDir, _SpecularMultiplier2);

				specularTerm = clamp(specularTerm, 0.0, 100.0); // Prevent FP16 overflo

				float EdotH = abs(dot(viewDir, halfDir));

				half3 lightScattering = _SubsurfaceColor;

				half3 color = (diffColor * DisneyDiffDir(lh, nl, nv, perceptualRoughness) * nl+ specColor * specularTerm ) * light.color
					+ gi.diffuse * (XShadeSH9(half4(normal, 1), lightScattering) + min(EdotH * lightScattering, 0.2)) * diffColor
					+ gi.specular * lerp(FresnelLerpFast(0.04, 1, nv), 0.04, _Color.rgb);

				return half4(color, 1);
			}

    		half4 fragBase (VertexOutput i) : SV_Target 
    		{    	  	    			
				half4 texo = tex2D(_MainTex, i.uv);
				half4 tex = texo * _Color;
				clip(tex.a - _CutOff);
				half4 metaGloss = tex2D(_MetallicGlossMap, i.uv);
				half3 albedo = tex.rgb;
				half metallic = metaGloss.r * _Metallic;
				half roughness = 1 - metaGloss.b * _GlossMapScale;
				half3 specColor = unity_ColorSpaceDielectricSpec.rgb* lerp(1.0, albedo * 0.5 + 0.5, roughness);
				half oneMinusReflectivity =  unity_ColorSpaceDielectricSpec.a;
				half3 diffColor = albedo * oneMinusReflectivity;				    

				half3 normal = UNITY_WORLD_NORMAL(i);	//世界坐标法线
				float3 posWorld = UNITY_WORLD_POS(i);
				half3 eyeVec = normalize(posWorld.xyz - _WorldSpaceCameraPos);

#if defined (XCHAR_SHADOW_ON)
				float3 shadowUV = i.shadowPos.xyz * 0.5 + 0.5;
#if 0
				float md = shadowUV.z - 0.001;
				float m = PCSS(shadowUV.xy, md);
#else
				float md = shadowUV.z - 0.001;
				float m = DiskF(shadowUV.xy, md);
#endif
				m = lerp(m, 1, _ShadowAttention);
				if (shadowUV.x > 1 || shadowUV.x < 0 || shadowUV.y > 1 || shadowUV.y < 0.0)
					m = 1;
#else
				float m = 1.0;
#endif

#if defined (XCHAR_SHADOW_ON)
				float atten = m;
#else
				UNITY_LIGHT_ATTENUATION(atten, i, posWorld);
#endif

				half occlusion = LerpOneTo (metaGloss.g, _OcclusionStrength);	

				half3 btangent = UNITY_WORLD_BINORMAL(i);
				half3 tangent = UNITY_WORLD_TANGENT(i);
				float3 iblNormalWS = GetAnisotropicModifiedNormal(btangent, normal, -eyeVec, _Metallic);
				half3 reflUVW = reflect(eyeVec, iblNormalWS);

				UnityLight light = (UnityLight)0;					    
				UnityIndirect gi=(UnityIndirect)0;		    			    
				light.dir = _WorldSpaceLightPos0.xyz;
				light.color = LightSaturate() * lerp(max(1 - _Color.rgb, 0.75), 1, atten);

			#if UNITY_SHOULD_SAMPLE_SH
				gi.diffuse = occlusion;
			#endif			    		   
				gi.specular = occlusion * XUnity_GlossyEnvironment(UNITY_PASS_TEXCUBE(unity_SpecCube0), unity_SpecCube0_HDR, max(roughness, 0.1), reflUVW);

			    half3 color = XBRDF2_Unity_PBS(diffColor, max(diffColor, specColor), oneMinusReflectivity, roughness, normal, tangent, btangent, -eyeVec, light, gi, metallic);

			#ifdef _EMISSION
				color.rgb += tex2D(_EmissionMap, i.uv).rgb * _EmissionColor.rgb;
			#endif				

				//Flash Light受击闪光
				half outer = 1.0 - saturate(dot(normalize(-eyeVec), normal));
				fixed3 emission = _OuterColor.rgb * pow(outer, _OuterPower) * _AllPower + (_InnerColor.rgb * 2 * _InnerColorPower);
				half alphaPower = (pow(outer, _AlphaPower))*_AllPower;
				color.rgb += emission * alphaPower;

			    return half4(color, tex.a);
			  
    		}  

			ENDCG
		}

		Pass
		{
			Name "FORWARD"
			Tags { "LightMode" = "ForwardBase" }
			ZWrite Off
			Blend SrcAlpha OneMinusSrcAlpha

			CGPROGRAM
			//#pragma target 2.0						

			//#pragma multi_compile __ UNITY_COLORSPACE_GAMMA

			//#pragma multi_compile __ _EMISSION					
			#pragma multi_compile_fwdbase
			//#pragma multi_compile_fog			
			#pragma multi_compile __ XCHAR_SHADOW_ON	

			#pragma exclude_renderers ps3 xbox360 flash xboxone ps4 psp2		
			#pragma skip_variants DYNAMICLIGHTMAP_ON DIRLIGHTMAP_COMBINED LIGHTMAP_ON LIGHTMAP_SHADOW_MIXING FOG_EXP FOG_EXP2

			#pragma vertex vertBase
			#pragma fragment fragBase						

			#include "UnityCG.cginc"
			#include "AutoLight.cginc"							
			#include "UnityStandardUtils.cginc"
			#include "UnityStandardBRDF.cginc"	
			#include "Common.cginc"	

			half4       _Color;
			sampler2D   _MainTex;
			float4      _MainTex_ST;

			sampler2D   _MetallicGlossMap;
			half 		_Metallic;
			half        _GlossMapScale;
			half        _OcclusionStrength;

			sampler2D	_EmissionMap;
			half4  		_EmissionColor;
			float		_CutOff;

			float _EnvBoost1;
			float _EnvBoost2;

			float _SpecularMultiplier;
			float _SpecularMultiplier2;
			float  _PrimaryShift;
			float _SecondaryShift;

			half4 _OuterColor;
			half _OuterPower;
			half _AlphaPower;
			half _AlphaMin;
			half _InnerColorPower;
			half _AllPower;
			half4 _InnerColor;

			struct VertexInput
			{
				float4 vertex   : POSITION;
				half3 normal    : NORMAL;
				float2 uv0      : TEXCOORD0;
				half4 tangent   : TANGENT;
			};

			struct VertexOutput
			{
				float4 pos : SV_POSITION;
				float2 uv : TEXCOORD0;
				//  half3 eyeVec : TEXCOORD1;
				  TBN_WORLD_COORDS(2, 3, 4)				// [3x3:tangentToWorld | 1x3:viewDirForParallax or worldPos]
				  half3 ambient : TEXCOORD5;    			// SH or Lightmap UV
#if defined (XCHAR_SHADOW_ON)
				  float4 shadowPos	: TEXCOORD6;
#else
				  UNITY_SHADOW_COORDS(6)
#endif
			  };

			//顶点着色
			VertexOutput vertBase(VertexInput v)
			{
				VertexOutput o = (VertexOutput)0;
				float4 posWorld = mul(unity_ObjectToWorld, v.vertex);

				o.pos = mul(UNITY_MATRIX_VP, posWorld);
				o.uv = TRANSFORM_TEX(v.uv0, _MainTex);
				//o.eyeVec = posWorld.xyz - _WorldSpaceCameraPos;
				float3 normalWorld = UnityObjectToWorldNormal(v.normal);
				TRANSFER_WORLD_POS(o, posWorld);

				float3 tangentWorld = UnityObjectToWorldDir(v.tangent.xyz);

				float sign = v.tangent.w * unity_WorldTransformParams.w;
				float3 binormal = cross(normalWorld, tangentWorld) * sign;


				TRANSFER_TBN_ROTATION(o, tangentWorld, binormal, normalWorld);

				half3 ambient = 0;

			#ifdef UNITY_SHOULD_SAMPLE_SH
				#ifdef VERTEXLIGHT_ON			            
					ambient = Shade4PointLights(unity_4LightPosX0, unity_4LightPosY0, unity_4LightPosZ0,
						unity_LightColor[0].rgb, unity_LightColor[1].rgb, unity_LightColor[2].rgb, unity_LightColor[3].rgb,
						unity_4LightAtten0, posWorld, normalWorld);
				#endif

				ambient = ShadeSHPerVertex(normalWorld, ambient);
			#endif
				o.ambient = ambient;

#if defined (XCHAR_SHADOW_ON)
				o.shadowPos = mul(_Global_ShadowMatrix, posWorld);
#else
				TRANSFER_SHADOW(o);
#endif
				return o;
			}

			half4  		_SubsurfaceColor;

		
			// Based on Minimalist CookTorrance BRDF
// Implementation is slightly different from original derivation: http://www.thetenthplanet.de/archives/255
//
// * NDF (depending on UNITY_BRDF_GGX):
//  a) BlinnPhong
//  b) [Modified] GGX
// * Modified Kelemen and Szirmay-​Kalos for Visibility term
// * Fresnel approximated with 1/LdotH
			half4 XBRDF2_Unity_PBS(half3 diffColor, half3 specColor, half oneMinusReflectivity, half rough,
				float3 normal, float3 tangent, float3 bitangent, float3 viewDir,
				UnityLight light, UnityIndirect gi, float anisotropy)
			{
				float3 h = float3(light.dir) + viewDir; // Unnormalized half-way vector  
				float3 halfDir = Unity_SafeNormalize(h);

				half onl = dot(normal, light.dir);
				half nl = saturate(onl);
				float nh = saturate(dot(normal, halfDir));
				half nv = saturate(dot(normal, viewDir));
				float lh = saturate(dot(light.dir, halfDir));

				// Specular term
				half perceptualRoughness = (rough);
				half roughness = PerceptualRoughnessToRoughness(perceptualRoughness);

				half shiftTex = anisotropy;
				half3 T = bitangent;

				half3 t1 = ShiftTangent(T, normal, _PrimaryShift + shiftTex);
				half3 t2 = ShiftTangent(T, normal, _SecondaryShift + shiftTex);

				//Specular term
				float specularTerm;
				specularTerm = _EnvBoost1* StrandSpecular(t1, viewDir, light.dir, _SpecularMultiplier) * lerp(1, nl, _Color.rgb);
				specularTerm += _EnvBoost2* StrandSpecularS(t2, viewDir, _SpecularMultiplier2);

				specularTerm = clamp(specularTerm, 0.0, 100.0); // Prevent FP16 overflow on mobiles

				float EdotH = abs(dot(viewDir, halfDir));

				half3 lightScattering = _SubsurfaceColor;

				half3 color = (diffColor * DisneyDiffDir(lh, nl, nv, perceptualRoughness)  * nl + specColor * specularTerm) * light.color
					+ gi.diffuse * (XShadeSH9(half4(normal, 1), lightScattering) + min(EdotH * lightScattering, 0.2)) * diffColor
					+ gi.specular * lerp(FresnelLerpFast(0.04, 1, nv), 0.04, _Color.rgb);

				return half4(color, 1);
			}

			half4 fragBase(VertexOutput i) : SV_Target
			{
				half4 texo = tex2D(_MainTex, i.uv);
				half4 tex = texo * _Color;
				clip(_CutOff - tex.a);
				half4 metaGloss = tex2D(_MetallicGlossMap, i.uv);
				half3 albedo = tex.rgb;
				half metallic = metaGloss.r * _Metallic;
				half roughness = 1 - metaGloss.b * _GlossMapScale;
				half3 specColor = unity_ColorSpaceDielectricSpec.rgb* lerp(1.0, albedo * 0.5 + 0.5, roughness);
				half oneMinusReflectivity = unity_ColorSpaceDielectricSpec.a;
				half3 diffColor = albedo * oneMinusReflectivity;

				half3 normal = UNITY_WORLD_NORMAL(i);	//世界坐标法线
				float3 posWorld = UNITY_WORLD_POS(i);
				half3 eyeVec = normalize(posWorld.xyz - _WorldSpaceCameraPos);

#if defined (XCHAR_SHADOW_ON)
				float3 shadowUV = i.shadowPos.xyz * 0.5 + 0.5;
#if 0
				float md = shadowUV.z - 0.001;
				float m = PCSS(shadowUV.xy, md);
#else
				float md = shadowUV.z - 0.001;
				float m = DiskF(shadowUV.xy, md);
#endif
				m = lerp(m, 1, _ShadowAttention);
				if (shadowUV.x > 1 || shadowUV.x < 0 || shadowUV.y > 1 || shadowUV.y < 0.0)
					m = 1;
#else
				float m = 1.0;
#endif

#if defined (XCHAR_SHADOW_ON)
				float atten = m;
#else
				UNITY_LIGHT_ATTENUATION(atten, i, posWorld);
#endif

				half occlusion = LerpOneTo(metaGloss.g, _OcclusionStrength);

				half3 btangent = UNITY_WORLD_BINORMAL(i);
				half3 tangent = UNITY_WORLD_TANGENT(i);
				float3 iblNormalWS = GetAnisotropicModifiedNormal(btangent, normal, -eyeVec, _Metallic);
				half3 reflUVW = reflect(eyeVec, iblNormalWS);

				UnityLight light = (UnityLight)0;
				UnityIndirect gi = (UnityIndirect)0;
				light.dir = _WorldSpaceLightPos0.xyz;
				light.color = LightSaturate() * lerp(max(1 - _Color.rgb, 0.75), 1, atten);

			#if UNITY_SHOULD_SAMPLE_SH
				gi.diffuse = occlusion;
			#endif			    		   
				gi.specular = occlusion * XUnity_GlossyEnvironment(UNITY_PASS_TEXCUBE(unity_SpecCube0), unity_SpecCube0_HDR, max(roughness, 0.1), reflUVW);

				half3 color = XBRDF2_Unity_PBS(diffColor, max(diffColor, specColor), oneMinusReflectivity, roughness, normal, tangent, btangent, -eyeVec, light, gi, metallic);

			#ifdef _EMISSION
				color.rgb += tex2D(_EmissionMap, i.uv).rgb * _EmissionColor.rgb;
			#endif				

				//Flash Light受击闪光
				half outer = 1.0 - saturate(dot(normalize(-eyeVec), normal));
				fixed3 emission = _OuterColor.rgb * pow(outer, _OuterPower) * _AllPower + (_InnerColor.rgb * 2 * _InnerColorPower);
				half alphaPower = (pow(outer, _AlphaPower))*_AllPower;
				color.rgb += emission * alphaPower;

				return half4(color, tex.a);

			}

			ENDCG
		}
		
		Pass
		{
			Name "ShadowCaster"
			Tags { "LightMode" = "ShadowCaster" }

			ZWrite On
			ZTest LEqual

			CGPROGRAM
			#pragma target 3.0									
			#pragma multi_compile_shadowcaster			
			#pragma vertex vertShadowCaster
			#pragma fragment fragShadowCaster

			sampler2D   _MainTex;
			float4      _MainTex_ST;
			float		_CutOff;

			#include "UnityCG.cginc"

			struct v2f
			{
				V2F_SHADOW_CASTER;
				float2 uv : TEXCOORD1;
			};

			v2f vertShadowCaster(appdata_base v)
			{
				v2f o;
				o.uv = TRANSFORM_TEX(v.texcoord, _MainTex);
				TRANSFER_SHADOW_CASTER_NORMALOFFSET(o)
				return o;
			}

			half4 fragShadowCaster(v2f i) : SV_Target
			{
				half4 diffuseColor = tex2D(_MainTex, i.uv);
				clip(diffuseColor.a - _CutOff);

				SHADOW_CASTER_FRAGMENT(i)
			}

			ENDCG
		}
	}
	
	//CustomEditor "CharacterShaderGUI"
}
