Shader "Actor/Character/Standard Alpha"
{
	Properties
	{
		_Color("Color", Color) = (1,1,1,1)
		_MainTex("Albedo", 2D) = "white" {}					
		_MetallicGlossMap("R(Metal)G(AO)B(Smoothness)", 2D) = "white" {}		
		_AlphaMap("Alpha Map", 2D) = "white" {}
		[Gamma]_Metallic("Metallic", Range(0.0, 1.0)) = 1.0
		_GlossMapScale("Smoothness", Range(0.0, 1.0)) = 1.0				
		_OcclusionStrength("Occlusion Strength", Range(0.0, 1.0)) = 1.0

		_BackIntensity("Back Intensity", Range(0, 1)) = 0.5

		_BumpMap("Normal Map", 2D) = "bump" {}	
		//_BumpScale("Bump Scale", Float) = 1.0	
		_EmissionColor("Emission Color", Color) = (0,0,0)
		_EmissionMap("Emission", 2D) = "white" {}	
	/*	_RimCol("Rim Color", Color) = (0, 0, 0, 1)
		_RimLight("Rim Light", Vector) = (0.1, 0.1, 0.1, 1)*/
		
		[Space]
		[Header(Clothing Dye)]
		[Space]
		[Toggle(_DYE)] _DYE("Need Dye?", Float) = 0
		_DyeMaskTex("Mask Texture (RGBA)", 2D) = "gray" {}	

		[Header(Color 1)]
		[HDR] _DyeColor0 ("Dye Color 1", Color) = (1,1,1,1)
		[Header(Color 2)]
		[HDR] _DyeColor1 ("Dye Color 2", Color) = (1,1,1,1)
		[Header(Color 3)]
		[HDR] _DyeColor2 ("Dye Color 3", Color) = (1,1,1,1)

		[Space(8)]
		[Header(Flash Light)]
		[Space]
		_OuterColor("Outer Color", Color) = (1,1,1,1)
		[HDR]_InnerColor("Inner Color", Color) = (1,1,1,1)
		_InnerColorPower("Inner Color Power", Range(0.0,1.0)) = 1
		_OuterPower("Outer Power", Range(0.0,5.0)) = 5
		_AlphaPower("Alpha Outer Power", Range(0.0,8.0)) = 8
		_AllPower("All Power", Range(0.0, 10.0)) = 0

		[Space(8)]
		[Header(Shen shi)]
		[Space]
		_IsShowInnerGlow("IsShowInnerGlow(0 or 1)",Range(0,1)) = 0
		[HDR]_InnerGlow("InnerGlow",Color) = (1,1,1,1)
		_InnerGlowPower("InnerGlowPower",Range(0,3)) = 1

		[HideInInspector] _Alpha ("Alpha", float) = 1
	}

	CGINCLUDE
	#pragma exclude_renderers ps3 xbox360 flash xboxone ps4 psp2		
	#pragma skip_variants DYNAMICLIGHTMAP_ON DIRLIGHTMAP_COMBINED LIGHTMAP_ON
	#pragma skip_variants SHADOWS_CUBE LIGHTMAP_SHADOW_MIXING SHADOWS_SHADOWMASK FOG_EXP FOG_EXP2

	#pragma multi_compile_fwdbase
	//#pragma multi_compile_fog
	#pragma multi_compile __ XCHAR_SHADOW_ON		
			
	#include "UnityCG.cginc"
	#include "AutoLight.cginc"							
	#include "UnityStandardUtils.cginc"
	#include "UnityStandardBRDF.cginc"	
	#include "Assets/CC_Shaders/CGINC/Common.cginc"

	half4       _Color;			
	sampler2D   _MainTex;
	float4      _MainTex_ST;
			
	sampler2D   _BumpMap;
	half        _BumpScale;

	sampler2D   _MetallicGlossMap;								
	half 		_Metallic;
	half        _GlossMapScale;					
	half        _OcclusionStrength;	

	sampler2D	_EmissionMap;
	half4  		_EmissionColor;
	sampler2D   _AlphaMap;

	//vector		_RimLight;
	//half4		_RimCol;

	sampler2D	_DyeMaskTex;
	half4		_DyeColor0;
	half4		_DyeColor1;
	half4		_DyeColor2;

	half4		_OuterColor;
	half		_OuterPower;
	half		_AlphaPower;
	half		_AlphaMin;
	half		_InnerColorPower;
	half		_AllPower;
	half4		_InnerColor;

	float		_IsShowInnerGlow;
	float4		_InnerGlow;
	half		_InnerGlowPower;

	half		_Alpha;

	float		_BackIntensity;

	struct VertexInput
	{
		float4 vertex   : POSITION;
		half3 normal    : NORMAL;
		float2 uv0      : TEXCOORD0;			    
		half4 tangent   : TANGENT;			    
	};

	struct VertexOutput
	{
		float4 pos		: SV_POSITION;
		float2 uv		: TEXCOORD0;
		half3 eyeVec	: TEXCOORD1;
		TBN_WORLD_COORDS(2, 3, 4)					// [3x3:tangentToWorld | 1x3:viewDirForParallax or worldPos]
		half3 ambient	: TEXCOORD5;    			// SH or Lightmap UV
		//UNITY_FOG_COORDS(7)
#if defined (XCHAR_SHADOW_ON)
		float4 shadowPos	: TEXCOORD6;
#else
		UNITY_SHADOW_COORDS(6)
#endif
	};

	inline half luminance(half3 c)
	{
		return max(max(c.r, c.g), c.b);
	}

	inline half3 ComputeAlbedo(half3 c, half4 adjColor)
	{
		half brightness = lerp(1, luminance(c), adjColor.a);
		adjColor.rgb = lerp(c.rgb, adjColor.rgb, adjColor.a);
		return brightness * adjColor.rgb;
	}

	//顶点着色
    VertexOutput vertBase (VertexInput v) 
    {    			
		VertexOutput o = (VertexOutput)0;			    		    			   			    
		float4 posWorld = mul(unity_ObjectToWorld, v.vertex);
							    
		o.pos = mul(UNITY_MATRIX_VP, posWorld);
		o.uv = TRANSFORM_TEX(v.uv0, _MainTex);
		o.eyeVec = posWorld.xyz - _WorldSpaceCameraPos;
		float3 normalWorld = UnityObjectToWorldNormal(v.normal);
		TRANSFER_WORLD_POS(o, posWorld);	

		float3 tangentWorld = UnityObjectToWorldDir(v.tangent.xyz);
		float sign = v.tangent.w * unity_WorldTransformParams.w;
		float3 binormal = cross(normalWorld, tangentWorld) * sign;

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
			    

		//UNITY_TRANSFER_FOG(o,o.pos);

#if defined (XCHAR_SHADOW_ON)
		o.shadowPos = mul(_Global_ShadowMatrix, posWorld);
#else
		TRANSFER_SHADOW(o);
#endif
		return o;    			
    }							    		

    half4 fragBase (VertexOutput i) : SV_Target 
    {    	  	    			
		half4 tex = half4(GammaToLinearSpace(tex2D(_MainTex, i.uv).rgb), 1);
		half4 metaGloss = half4((tex2D(_MetallicGlossMap, i.uv).rgb), 1);

		half4 texAlpha = tex2D(_AlphaMap, i.uv);
		half3 albedo = _Color.rgb * tex.rgb;	
	#ifdef _DYE
		half4 mask = tex2D(_DyeMaskTex, i.uv.xy);
		half dyeSign0 = mask.r - mask.g - mask.b;
		half dyeSign1 = mask.g;
		half dyeSign2 = mask.b;
		half otherSign = mask.a;

		half3 dyeColor0 = ComputeAlbedo(albedo, _DyeColor0);
		half3 dyeColor1 = ComputeAlbedo(albedo, _DyeColor1);
		half3 dyeColor2 = ComputeAlbedo(albedo, _DyeColor2);
		albedo = saturate(half3(dyeColor0 * dyeSign0 + dyeColor1 * dyeSign1 + dyeColor2 * dyeSign2 + albedo * otherSign));
	#endif

		half metallic = metaGloss.r * _Metallic;			    			    
		half smoothness = metaGloss.b * _GlossMapScale;					    

		half3 dielectric = unity_ColorSpaceDielectricSpec.rgb* lerp(1.0, albedo * 0.5 + 0.5, 1 - smoothness);
		half3 specColor = lerp(dielectric, albedo, metallic);
		half oneMinusReflectivity = (1 - metallic) * unity_ColorSpaceDielectricSpec.a;
		half3 diffColor = albedo * oneMinusReflectivity;				    

		half3 normal = UNPACK_WORLD_NORMAL(_BumpMap, i.uv, i);	//世界坐标法线
		half3 eyeVec = normalize(i.eyeVec);
		float3 posWorld = UNITY_WORLD_POS(i);

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
		half roughness = 1 - smoothness;
		half3 reflUVW = reflect(eyeVec, normal);    

		UnityLight light = (UnityLight)0;					    
		UnityIndirect gi = (UnityIndirect)0;
		light.dir = _WorldSpaceLightPos0.xyz;
		light.color = _LightColor0.rgb * atten;	

	#if UNITY_SHOULD_SAMPLE_SH
		gi.diffuse = occlusion * ShadeSHPerPixel (normal, i.ambient, posWorld);			        
	#endif			    		   
		gi.specular = occlusion * Unity_GlossyEnvironment (UNITY_PASS_TEXCUBE(unity_SpecCube0), unity_SpecCube0_HDR, roughness, reflUVW);				

		half3 viewDir = -eyeVec;
		half perceptualRoughness = roughness;
		half3 halfDir = Unity_SafeNormalize (light.dir + viewDir);


		half onl = dot(normal, light.dir);
		half nv = saturate(dot(normal, viewDir));    
		half nl = saturate(onl);
		half nh = saturate(dot(normal, halfDir));			    
		half lh = saturate(dot(light.dir, halfDir));

		roughness = perceptualRoughness * perceptualRoughness;
		half a = roughness;
		half a2 = a * a;
		half d = nh * nh * (a2 - 1.h) + 1.00001h;

		half specularTerm = a / (max(0.32h, lh) * (1.5h + roughness) * d);

		specularTerm = specularTerm - 1e-4h;
		specularTerm = clamp(specularTerm, 0.0, 100.0); 	// Prevent FP16 overflow on mobiles

		half surfaceReduction = 0.28;

		surfaceReduction = 1.0 - roughness * perceptualRoughness * surfaceReduction;
		half grazingTerm = saturate(smoothness + (1 - oneMinusReflectivity)); //F90

		float d2 = nv * nv * (a2 - 1.f) + 1.00001f;
		float specularTerm2 = a2 / ((roughness + 0.5f) * (d2 * d2) * 18);
		specularTerm2 = clamp(specularTerm2, 0.0, 100.0); // Prevent FP16 overflow on mobiles

		float fndl = onl * 0.5 + 0.5;

		half3 color = (diffColor + specularTerm * specColor) * light.color * nl + gi.diffuse * diffColor *(1 + _BackIntensity * (1 - fndl)) + _LightColor0.rgb * specularTerm2 * specColor
			+ surfaceReduction * gi.specular * FresnelLerpFast(specColor, grazingTerm, nv);

		color.rgb = LinearToGammaSpace(color.rgb);

		//Emission
		color.rgb += tex2D(_EmissionMap, i.uv).rgb * _EmissionColor.rgb;

		//RimLight边缘光
		//color.rgb += clamp(pow(dot(saturate(normal * _RimLight.rgb + _RimLight.a), 1.0 - nv), 5 * _RimCol.a) * _RimCol.rgb, 0, 4);

		//Flash Light受击闪光
		fixed3 emission = _OuterColor.rgb * pow(1.0 - nv, _OuterPower) * _AllPower + (_InnerColor.rgb * 2 * _InnerColorPower);
		half alphaPower = (pow(1.0 - nv, _AlphaPower)) * _AllPower;
		color.rgb += emission * alphaPower;

		//Shenshi神识
		color.rgb += _InnerGlow * pow((1 - nv) * _IsShowInnerGlow, _InnerGlowPower) *2;

		half alpha = texAlpha.r * _Alpha;

		//UNITY_APPLY_FOG(i.fogCoord, color);	
				
		return BS2EncodeHDR(half4(color, alpha));
    }  
	ENDCG

	SubShader
	{
		Tags { "RenderType"="Opaque" "Queue"="AlphaTest+49" }
		LOD 400
	
		Pass
		{
			Name "FORWARD" 
			Tags { "LightMode" = "ForwardBase" }							

			Blend SrcAlpha OneMinusSrcAlpha, One One

			CGPROGRAM	
			#pragma vertex vertBase
			#pragma fragment fragBase
			#pragma multi_compile __ _DYE						//染色
			ENDCG
		}
		
		UsePass "Actor/Character/Standard/SHADOWCASTER"
	}

	SubShader
	{
		Tags { "RenderType"="Opaque" "Queue"="AlphaTest+49" }
		LOD 300
	
		Pass
		{
			Name "FORWARD" 
			Tags { "LightMode" = "ForwardBase" }							

			Blend SrcAlpha OneMinusSrcAlpha, One One

			CGPROGRAM	
			#pragma vertex vertBase
			#pragma fragment fragBase
			#pragma multi_compile __ _DYE						//染色
			ENDCG
		}
		
		UsePass "Actor/Character/Standard/SHADOWCASTER"
	}

	SubShader
	{
		Tags { "RenderType"="Opaque" "Queue"="AlphaTest+49" }
		LOD 0
	
		Pass
		{
			Name "FORWARD" 
			Tags { "LightMode" = "ForwardBase" }
			
			Blend SrcAlpha OneMinusSrcAlpha, One One

			CGPROGRAM	
			#pragma vertex vertBase
			#pragma fragment fragBase
			#pragma multi_compile __ _DYE						//染色
			ENDCG
		}
	}
}

