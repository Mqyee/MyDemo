Shader "Scene/Water/BathWater" 
{ 
    Properties 
    {       
		_ReflectionCube ("Reflection Cube", Cube) = "_skybox" {}

		[Space]
		_WaterColor ("Water Color", Color) = (0.10, 0.20, 0.30, 0.50)

		_OpacityDepth("OpacityDepth", Float) = 5

		[HDR] _HighColor ("High Color", Color) = (0.5, 0.8, 1, 1)

		_ScatterColor("Scatter Color", Color) = (0.10, 0.20, 0.30, 0.50)
		_ScatterDepth("ScatterDepth", Float) = 5

        _WaveScale1 ("Wave Scale 1", Range (0.02, 1)) = 0.4
		_WaveScale2 ("Wave Scale 2", Range (0.02, 1)) = 0.3
        _WaveSpeed ("Wave Speed", Vector) = (1, -1, 3, 1)  

		[Space(20)]
		_Normalmap ("NormalMap", 2D) = "bump" {}
        _NormalIntensity ("Normal Intensity", Range(0, 1)) = 0.40     
		_RefractIntensity ("Refract Intensity", Range(0, 1)) = 0.20    
		_ReflectIntensity ("Reflect Intensity", Range(0, 1)) = 1
           
    }

	CGINCLUDE
    #include "UnityCG.cginc"
    #include "Lighting.cginc"
    #include "AutoLight.cginc"
    #include "UnityStandardBRDF.cginc"

    #pragma skip_variants DYNAMICLIGHTMAP_ON DIRLIGHTMAP_COMBINED FOG_EXP1 FOG_EXP2 VERTEXLIGHT_ON   
    #pragma skip_variants LIGHTMAP_ON LIGHTMAP_SHADOW_MIXING SHADOWS_SHADOWMASK 
 
	float4		_WaterColor;
	float4		_HighColor;
	float		_WaveScale1;
	float		_WaveScale2;
	vector		_WaveSpeed;

	sampler2D	_Normalmap;
    float4		_Normalmap_ST;
	float		_NormalIntensity;
	float		_RefractIntensity;

	float		_ScatterDepth;
	float		_ReflectIntensity;
	half4		_ScatterColor;
	float		_OpacityDepth;

	uniform sampler2D _CameraDepthTexture;
	uniform sampler2D _CustomGrabTexture;

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
		float4 waveScale = _Normalmap_ST.xyxy * float4(_WaveScale1.xx, _WaveScale2.xx) * 10;
        o.uv = v.texcoord.xyxy * waveScale + _WaveSpeed * 0.1 * _Time.x * phi;

        return o;
    }      

    half4 frag300( v2f i ) : SV_Target
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

		half3 bump = normalize(bump1 + bump2);
		bump = lerp(half3(0,0,1), half3(bump.x, bump.y, 1), _NormalIntensity);                        
		half3 normal = normalize(i.tangent.xyz * bump.x + i.binormal.xyz * bump.y + i.normal.xyz * bump.z);

		float ndotv = saturate(dot(normal, viewDir));

		float2 distort = bump.xy * _RefractIntensity * 0.05;

		float2 grabUV = (i.screenPos.xy + distort) / i.screenPos.w;

#if UNITY_UV_STARTS_AT_TOP
		if (_ProjectionParams.x > 0)
			grabUV.y = 1 - grabUV.y;
#endif		

		float sceneZ = max(0, LinearEyeDepth(UNITY_SAMPLE_DEPTH(tex2D(_CameraDepthTexture, grabUV))) - _ProjectionParams.g);
		float partZ = max(0, i.screenPos.w - _ProjectionParams.g);

		float depthWater = saturate((sceneZ - partZ) / _OpacityDepth);
		float depthScatter = saturate((sceneZ - partZ) / _ScatterDepth);
		
		half4 color = lerp(_ScatterColor, _WaterColor, depthScatter);

		float4 fresnelFac = color + (1 - color) * pow((1 - ndotv), 4);

		fixed4 refractionCol = tex2D(_CustomGrabTexture, grabUV);

		float3 viewReflectDir = reflect(-viewDir, normal);

		float alpha = saturate(depthWater * (ndotv + _WaterColor.a));

		half4 reflectionCubeCol = half4(CubemapSampler(reflect(-viewDir, normal)), 1);
		reflectionCubeCol = lerp(_LightColor0, reflectionCubeCol, _ReflectIntensity);

		color.rgb = lerp(color.rgb, _HighColor.rgb * reflectionCubeCol.rgb, fresnelFac);
		color.rgb = lerp(refractionCol.rgb, color.rgb, alpha);
        
		color = half4(clamp(color.rgb, 0, 36), 1);

        return color;
    }

	half4 frag200(v2f i) : SV_Target
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

		half3 bump = normalize(bump1 + bump2);
		bump = lerp(half3(0,0,1), half3(bump.x, bump.y, 1), _NormalIntensity);
		half3 normal = normalize(i.tangent.xyz * bump.x + i.binormal.xyz * bump.y + i.normal.xyz * bump.z);

		float ndotv = saturate(dot(normal, viewDir));

		float depthWater = _HighColor.a;
		float depthScatter = _ScatterColor.a;

		half4 color = lerp(_ScatterColor, _WaterColor, depthScatter);

		float4 fresnelFac = color + (1 - color) * pow((1 - ndotv), 4);

		float3 viewReflectDir = reflect(-viewDir, normal);

		float alpha = saturate(depthWater  * (ndotv + _WaterColor.a) );

		half4 reflectionCubeCol = half4(CubemapSampler(reflect(-viewDir, normal)), 1);
		reflectionCubeCol = lerp(_LightColor0, reflectionCubeCol, _ReflectIntensity);

		color.rgb = lerp(color.rgb, _HighColor.rgb * reflectionCubeCol.rgb, fresnelFac);

		color = half4(clamp(color.rgb, 0, 36), alpha);

		return color;
	}
	ENDCG

    Subshader
    {
        Tags {"RenderType"="Transparent" "IgnoreProjector"="True" "Queue"="Transparent-11"}

        Lod 300     

        Pass 
        {             
            Tags { "LightMode" = "ForwardBase" }           

            CGPROGRAM     
			#pragma vertex vert
            #pragma fragment frag300
            #pragma multi_compile_fwdbase

            ENDCG
        }
    }   

	Subshader
	{
		Tags {"RenderType" = "Transparent" "IgnoreProjector" = "True" "Queue" = "Transparent-11"}

		Lod 200

		Pass
		{
			Tags { "LightMode" = "ForwardBase" }

			Blend SrcAlpha OneMinusSrcAlpha

			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag200
			#pragma multi_compile_fwdbase

			ENDCG
		}
	}

}
