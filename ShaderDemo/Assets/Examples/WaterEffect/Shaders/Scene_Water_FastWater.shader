Shader "Scene/Water/FastWater" 
{ 
	Properties
	{
			_BaseColor("Base color", COLOR) = (.54, .95, .99, 1)
			[HDR]_HighColor("High color", COLOR) = (.54, .95, .99, 0.05)
			_Fresnel("Fresnel", Range(0.04, 1)) = 0.33
			_WaveScale("Wave scale", Range(0.02,0.5)) = 0.094
			_WaveScale2("Wave scale 2", Range(0.02,0.5)) = 0.501
			_WaveOffset("Wave speed (map1 x,y; map2 x,y)", Vector) = (0.5,-0.5,-0.5,0.5)
			[NoScaleOffset] _BumpMap("Normalmap ", 2D) = "bump" {}
			_WaveBump("Wave bump", Range(0.02, 2)) = 0.701
			_WaveHeight("Wave Height", Range(0.02, 1)) = 1
			_WaveFreq("Wave Freq", Range(0.02, 5)) = 3

			[NoScaleOffset]_SpecCube0("SpecCube0", CUBE) = "" { }
			_Angle("Angle", Range(0, 360)) = 180

			_Shininess("Specness", Float) = 128
			_LightDirection("Light Direction", Vector) = (1,1,1,1)
	}

		Subshader{
		Tags{ "RenderType" = "Transparent" "Queue" = "Transparent" }

		Lod 200
		GrabPass{"_CustomGrabTexture"}
		Pass
		{
			Tags{
				"LightMode" = "ForwardBase"
			}

			CGPROGRAM
				#pragma vertex vert
				#pragma fragment frag
				#pragma multi_compile __ XJ4_REFRESH_ON
				#pragma fragmentoption ARB_precision_hint_fastest

				#include "UnityCG.cginc"
				#include "Lighting.cginc"
				#include "AutoLight.cginc"
				#include "UnityStandardBRDF.cginc"
				#pragma multi_compile_fog

				uniform float _WaveScale;
				uniform float _WaveScale2;
				uniform float4 _WaveOffset;
				uniform float _WaveBump;
				uniform fixed4 _BaseColor;
				uniform fixed4 _HighColor;
				uniform float _Fresnel;
				uniform sampler2D _BumpMap;
				uniform samplerCUBE _SpecCube0;
				uniform float _Shininess;
				uniform float _WaveHeight;
				uniform float _WaveFreq;
				float _Angle;
				uniform half4 _SpecCube0_HDR;
				sampler2D	_CustomGrabTexture;
				float4 _CustomGrabTexture_TexelSize;
				float4 _LightDirection;

				struct v2f {
					float4 pos : SV_POSITION;
					float4 bumpuv : TEXCOORD0;
					float4 viewDir : TEXCOORD1;
					half4 screenPos : TEXCOORD2;
					UNITY_FOG_COORDS(3)
				};

				struct appdata_t {
					float4 vertex : POSITION;
					fixed4 color : COLOR;
				};

				v2f vert(appdata_t v)
				{
					v2f o = (v2f)0;
					o.pos = UnityObjectToClipPos(v.vertex);

					// scroll bump waves
					float4 wpos = mul(unity_ObjectToWorld, v.vertex);
					wpos.xz += cos((_Time.x * _WaveFreq.xx) + wpos.xz * half2(_WaveScale.x, _WaveScale2.x)) * _WaveHeight;

					o.bumpuv.xyzw = wpos.xzxz * half4(_WaveScale.xx, _WaveScale2.xx) + _WaveOffset * _Time.x;

					o.viewDir.xyz = wpos.xyz;
					o.viewDir.w = v.color.a;
					o.screenPos = ComputeScreenPos(o.pos);
					UNITY_TRANSFER_FOG(o,o.pos);
					return o;
				}

				inline half3 glossCubeLookup(float3 worldRefl) {

					half4 skyData = texCUBE(_SpecCube0, worldRefl);

					return DecodeHDR(skyData, _SpecCube0_HDR).rgb;
				}

				float3 RotateAroundYInDegrees(float3 vertex, float degrees)
				{
					float alpha = degrees * UNITY_PI / 180.0;
					float sina, cosa;
					sincos(alpha, sina, cosa);
					float2x2 m = float2x2(cosa, -sina, sina, cosa);
					return float3(mul(m, vertex.xz), vertex.y).xzy;
				}

				half4 frag(v2f i) : SV_Target
				{
					// combine two scrolling bumpmaps into one
					fixed4 bump1 = tex2D(_BumpMap, i.bumpuv.xy);
					fixed4 bump2 = tex2D(_BumpMap, i.bumpuv.zw);
					half3 bump = UnpackNormal((bump1 + bump2) * 0.5);
					bump.xz = bump.xy * _WaveBump;
					bump.y = 1;
					bump = normalize(bump);

					// fresnel factor
					half3 uview = normalize(UnityWorldSpaceViewDir(i.viewDir.xyz));
					half4 fresnelFac = _Fresnel + (1 - _Fresnel) *(1 - dot(uview, bump));
					half3 skyRefl = reflect(-uview, bump);
					fixed4 rtReflections = half4(glossCubeLookup(RotateAroundYInDegrees(skyRefl, _Angle)), 1);
					half4 water = lerp(_BaseColor, _HighColor* rtReflections, fresnelFac);

					water.a = _BaseColor.a * i.viewDir.w;
					half2 refrCoord = (i.screenPos.xy) / i.screenPos.w + bump.xz * _HighColor.a;

				#if UNITY_UV_STARTS_AT_TOP
					if (_ProjectionParams.x > 0)
						refrCoord.y = 1 - refrCoord.y;
				#endif		

					fixed4 refractions = tex2D(_CustomGrabTexture, refrCoord);
					water = lerp(refractions, water, water.a);
					half3 viewReflectDir = reflect(-uview, bump);
					float3 specular = _LightDirection.w * _LightColor0.rgb * pow(abs(dot(normalize(_LightDirection.xyz), viewReflectDir)), _Shininess);
					water.rgb += specular * fresnelFac;
					UNITY_APPLY_FOG(i.fogCoord, water);
					return water;
				}
			ENDCG

		}
	}

	Fallback Off
}
