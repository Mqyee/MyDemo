Shader "Scene/Water/NormalWater" 
{ 
    Properties 
    {       
		[Enum(Off, 0, On, 1)] _Reflection ("Open Reflection?", Float) = 1
		_ReflectionCube ("Reflection Cube", Cube) = "_skybox" {}

		[Space]
		_WaterColor ("Water Color", Color) = (0.10, 0.20, 0.30, 0.50)
		[HDR] _HighColor ("High Color", Color) = (0.5, 0.8, 1, 1)
        _WaveScale1 ("Wave Scale 1", Range (0.02, 1)) = 0.4
		_WaveScale2 ("Wave Scale 2", Range (0.02, 1)) = 0.3
        _WaveSpeed ("Wave Speed", Vector) = (1, -1, 3, 1)  

		[Space(20)]
		_Normalmap ("NormalMap", 2D) = "bump" {}
        _NormalIntensity ("Normal Intensity", Range(0, 1)) = 0.40     
		_RefractIntensity ("Refract Intensity", Range(0, 1)) = 0.20    
        
		[Space(20)]
		_Specular ("Specular", Range(0.002, 1)) = 0.5
		_Gloss ("Gloss", Range(0.002, 1)) = 0.5
		[HDR] _SpecularColor ("Spec Color", Color) = (1, 1, 1, 1)

		[Space(20)]
		_Fresnel ("Fresnel", Range(0, 1)) = 0.35
		_FresnelPow ("Fresnel Pow", Range(0.14, 1)) = 0.7
		_ReflectIntensity ("Reflect Intensity", Range(0, 1)) = 1

		[HideInInspector] _ReflectionTex ("Internal Reflection", 2D) = "" {}            
    }

	CGINCLUDE
    #include "UnityCG.cginc"
    #include "Lighting.cginc"
    #include "AutoLight.cginc"
    #include "UnityStandardBRDF.cginc"
    #pragma skip_variants DYNAMICLIGHTMAP_ON DIRLIGHTMAP_COMBINED FOG_EXP1 FOG_EXP2 VERTEXLIGHT_ON   
    #pragma skip_variants LIGHTMAP_ON LIGHTMAP_SHADOW_MIXING SHADOWS_SHADOWMASK 
 
	half4		_WaterColor;  
	half4		_HighColor;
	half		_WaveScale1;
	half		_WaveScale2;
	vector		_WaveSpeed;

	sampler2D	_Normalmap;
    float4		_Normalmap_ST;
	half		_NormalIntensity;
    half		_RefractIntensity;    
    
	float		_Specular;
	float		_Gloss;
	half4		_SpecularColor;

	half		_Fresnel;
	half		_FresnelPow;
	half		_ReflectIntensity;

	sampler2D	_ReflectionTex;
	uniform sampler2D	_CustomGrabTexture;

	float		_Reflection;
	UNITY_DECLARE_TEXCUBE(_ReflectionCube);
	float4 _ReflectionCube_HDR;

	float3 CubemapSampler(float3 rDir)
	{
		float4 env = UNITY_SAMPLE_TEXCUBE(_ReflectionCube, rDir);
		return DecodeHDR(env, _ReflectionCube_HDR);
	}

    struct v2f 
    {
        float4 pos			: SV_POSITION; 
		float4 uv			: TEXCOORD0;
		float4 normal		: TEXCOORD1;
		float4 tangent		: TEXCOORD2;
		float4 binormal		: TEXCOORD3;
		float4 screenPos	: TEXCOORD4;
    };

    v2f vert(appdata_tan v)
    {
		v2f o;
		UNITY_INITIALIZE_OUTPUT(v2f, o);

		o.pos = UnityObjectToClipPos(v.vertex);
		o.screenPos = ComputeNonStereoScreenPos(o.pos);

		float3 worldPos = mul(unity_ObjectToWorld, v.vertex);
		float3 worldNormal = UnityObjectToWorldNormal(v.normal);

		o.tangent.xyz = UnityObjectToWorldDir(v.tangent.xyz);
		o.binormal.xyz = cross(worldNormal, o.tangent.xyz) * v.tangent.w * unity_WorldTransformParams.w;
		o.normal.xyz = worldNormal;

        o.tangent.w = worldPos.x;
        o.binormal.w = worldPos.y;
        o.normal.w = worldPos.z;

		const float phi = 1.61803398875; 
		float4 waveScale = _Normalmap_ST.xyxy * half4(_WaveScale1.xx, _WaveScale2.xx) * 10; 
        o.uv = v.texcoord.xyxy * waveScale + _WaveSpeed * 0.1 * _Time.x * phi;

        return o;
    }      

    half4 frag400( v2f i ) : SV_Target
    {                        
		half3 worldPos = half3(i.tangent.w, i.binormal.w, i.normal.w);
		half3 viewDir = normalize(_WorldSpaceCameraPos - worldPos);
	#ifndef USING_DIRECTIONAL_LIGHT
		half3 lightDir = normalize(UnityWorldSpaceLightDir(worldPos));
	#else
		half3 lightDir = _WorldSpaceLightPos0.xyz;
	#endif        
        
		half3 bump1 = UnpackNormal(tex2D(_Normalmap, i.uv.xy));
		half3 bump2 = UnpackNormal(tex2D(_Normalmap, i.uv.zw));
		half3 bump = bump1 + bump2;
		bump = lerp(half3(0,0,1), half3(bump.x, bump.y, 1), _NormalIntensity);                        
		half3 normal = normalize(i.tangent.xyz * bump.x + i.binormal.xyz * bump.y + i.normal.xyz * bump.z);

		half halfDir = normalize(viewDir + lightDir);
		half ndotv = saturate(dot(normal, viewDir));
		half ndotL = saturate(dot(normal, lightDir));
		half ndoth = saturate(dot(normal, halfDir));

		float2 distort = bump.xy * _RefractIntensity * 0.05;

		half fresnelFac = _Fresnel + (1 - _Fresnel) * pow((1 - ndotv), _FresnelPow * 7);

		float2 grabUV = (i.screenPos.xy + distort * 7.5) / i.screenPos.w;

#if UNITY_UV_STARTS_AT_TOP
		if (_ProjectionParams.x > 0)
			grabUV.y = 1 - grabUV.y;
#endif		

		fixed4 refractionCol = tex2D(_CustomGrabTexture, grabUV);

		half3 viewReflectDir = reflect(-viewDir, normal);
		float3 lightFac = clamp(_LightColor0.rgb, 0.01, 1);
		float3 specular = _Specular*25*lightFac*_SpecularColor*pow(max(0,dot(lightDir,viewReflectDir)),exp((_Gloss*9.0+1.0)));
		
		half4 color = _WaterColor;
		color.a = saturate(color.a * 0.7 + 0.3);

		fixed4 reflectionCol = tex2D(_ReflectionTex, i.screenPos.xy/i.screenPos.w + distort);
		half4 reflectionCubeCol = half4(CubemapSampler(reflect(-viewDir, lerp(i.normal.xyz, normal, 0.1))), 1); 
		reflectionCol = lerp(reflectionCubeCol, reflectionCol, _Reflection);
		reflectionCol = lerp(_WaterColor, reflectionCol, _ReflectIntensity);

		color.rgb = lerp(color.rgb, _HighColor.rgb * reflectionCol.rgb, fresnelFac);
		color.rgb = lerp(refractionCol.rgb, color.rgb, color.a);
		color.rgb += specular * (1 - fresnelFac);
        
		color = half4(clamp(color.rgb, 0, 36), saturate(_HighColor.a));
		//UNITY_APPLY_FOG(i.fogCoord, color); 

        return color;
    }
	ENDCG

    Subshader
    {
        Tags {"RenderType"="Transparent" "IgnoreProjector"="True" "Queue"="Transparent-11"}

        Lod 400     

        Pass 
        {             
            Tags { "LightMode" = "ForwardBase" }     
            
            Blend SrcAlpha OneMinusSrcAlpha            

            CGPROGRAM     
			#pragma vertex vert
            #pragma fragment frag400
            #pragma multi_compile_fwdbase

            ENDCG
        }
    }   

	Subshader
    {
        Tags {"RenderType"="Transparent" "IgnoreProjector"="True" "Queue"="Transparent-11"}

        Lod 300     

        Pass 
        {             
            Tags { "LightMode" = "ForwardBase" }     
            
            Blend SrcAlpha OneMinusSrcAlpha            

            CGPROGRAM     
			#pragma vertex vert
            #pragma fragment frag300
            #pragma multi_compile_fwdbase

			half4 frag300( v2f i ) : SV_Target
			{                        
				half3 worldPos = half3(i.tangent.w, i.binormal.w, i.normal.w);
				half3 viewDir = Unity_SafeNormalize(_WorldSpaceCameraPos - worldPos);
			#ifndef USING_DIRECTIONAL_LIGHT
				half3 lightDir = normalize(UnityWorldSpaceLightDir(worldPos));
			#else
				half3 lightDir = _WorldSpaceLightPos0.xyz;
			#endif        
        
				half3 bump1 = UnpackNormal(tex2D(_Normalmap, i.uv.xy));
				half3 bump2 = UnpackNormal(tex2D(_Normalmap, i.uv.zw));
				half3 bump = bump1 + bump2;
				bump = lerp(half3(0,0,1), half3(bump.x, bump.y, 1), _NormalIntensity);                        
				half3 normal = normalize(i.tangent.xyz * bump.x + i.binormal.xyz * bump.y + i.normal.xyz * bump.z);

				half halfDir = Unity_SafeNormalize(viewDir + lightDir);
				half ndotv = saturate(dot(normal, viewDir));
				half ndotL = saturate(dot(normal, lightDir));
				half ndoth = saturate(dot(normal, halfDir));

				half fresnelFac = _Fresnel + (1 - _Fresnel) * pow((1 - ndotv), _FresnelPow * 7);

				half3 viewReflectDir = reflect(-viewDir, normal);
				float3 lightFac = clamp(_LightColor0.rgb, 0.01, 1);
				float3 specular = _Specular*25*lightFac*_SpecularColor*pow(max(0,dot(lightDir,viewReflectDir)),exp(_Gloss*9.0));
		
				half4 color = _WaterColor;
				color.a = saturate(color.a * 0.7 + 0.3);

				half4 reflectionCubeCol = half4(CubemapSampler(reflect(-viewDir, lerp(i.normal.xyz, normal, 0.2))), 1); 

				color.rgb = lerp(color.rgb, _HighColor.rgb * reflectionCubeCol.rgb, fresnelFac);
				color.rgb += specular;
        
				color.rgb = clamp(color.rgb, 0, 36);

				return color;
			}

            ENDCG
        }
    }   

	Subshader
    {
        Tags {"RenderType"="Transparent" "IgnoreProjector"="True" "Queue"="Transparent-11"}

        Lod 200     

        Pass 
        {             
            Tags { "LightMode" = "ForwardBase" }     
            
            Blend SrcAlpha OneMinusSrcAlpha            

            CGPROGRAM     
			#pragma vertex vert
            #pragma fragment frag200
            #pragma multi_compile_fwdbase 
			
			half4 frag200( v2f i ) : SV_Target
			{                        
				half3 worldPos = half3(i.tangent.w, i.binormal.w, i.normal.w);
				half3 viewDir = Unity_SafeNormalize(_WorldSpaceCameraPos - worldPos);
			#ifndef USING_DIRECTIONAL_LIGHT
				half3 lightDir = normalize(UnityWorldSpaceLightDir(worldPos));
			#else
				half3 lightDir = _WorldSpaceLightPos0.xyz;
			#endif        
        
				half3 bump1 = UnpackNormal(tex2D(_Normalmap, i.uv.xy));
				half3 bump2 = UnpackNormal(tex2D(_Normalmap, i.uv.zw));
				half3 bump = bump1 + bump2;
				bump = lerp(half3(0,0,1), half3(bump.x, bump.y, 1), _NormalIntensity);                        
				half3 normal = normalize(i.tangent.xyz * bump.x + i.binormal.xyz * bump.y + i.normal.xyz * bump.z);

				half halfDir = Unity_SafeNormalize(viewDir + lightDir);
				half ndotv = saturate(dot(normal, viewDir));
				half ndotL = saturate(dot(normal, lightDir));
				half ndoth = saturate(dot(normal, halfDir));

				half fresnelFac = _Fresnel + (1 - _Fresnel) * pow((1 - ndotv), _FresnelPow * 7);

				half4 color = _WaterColor;
				color.a = saturate(color.a * 0.7 + 0.3);

				half4 reflectionCubeCol = half4(CubemapSampler(reflect(-viewDir, lerp(i.normal.xyz, normal, 0.2))), 1); 
				color.rgb = lerp(color.rgb, _HighColor.rgb * reflectionCubeCol.rgb, fresnelFac);
				color.rgb = clamp(color.rgb, 0, 36);

				return color;
			}
            ENDCG
        }
    }   
}
