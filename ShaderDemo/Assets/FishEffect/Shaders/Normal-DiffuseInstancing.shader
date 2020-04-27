Shader "Actor/AnimationInstancing/DiffuseInstancing" 
{
	Properties 
	{
		[HDR]_Color ("Main Color", Color) = (1,1,1,1)
		_MainTex ("Base (RGB)", 2D) = "white" {}
		[Toggle(_SHOW_INNER_EFFECT)]_ShowInnerEffect("ShowInnerEffect",float) = 0
		[HDR]_InnerColor("InnerColor",Color) = (1,1,1,1)
		_InnerPower("InnerPower",Range(1,10)) = 8
	}

	SubShader 
	{
		Tags { "RenderType"="Opaque" }

		LOD 200

		Pass
		{
			CGPROGRAM
			#include "UnityCG.cginc"
			#include "AnimationInstancingBase.cginc"
			#pragma multi_compile_instancing
			#pragma vertex vert_a 
			#pragma fragment frag
			#pragma multi_compile	__ _SHOW_INNER_EFFECT
			#pragma multi_compile __ FOG_LINEAR	

			struct v2f 
			{
				 float4 pos			: SV_POSITION;
				 float2 uv			: TEXCOORD0;
				 float3 worldPos	: TEXCOORD1;
				float3 normal : TEXCOORD2;

				 UNITY_FOG_COORDS(3)
				 UNITY_VERTEX_INPUT_INSTANCE_ID
				 UNITY_VERTEX_OUTPUT_STEREO
			};

			sampler2D _MainTex;
			float4 _MainTex_ST;
			fixed4 _Color;
			fixed4 _InnerColor;
			half _InnerPower;

			v2f vert_a(appdata_full v)
			{
				UNITY_SETUP_INSTANCE_ID(v);
				v2f o;
				UNITY_INITIALIZE_OUTPUT(v2f,o);
				UNITY_TRANSFER_INSTANCE_ID(v,o);
				UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);
				vert(v);
				o.pos = UnityObjectToClipPos(v.vertex);
				o.uv = TRANSFORM_TEX(v.texcoord, _MainTex);
				o.worldPos = mul(unity_ObjectToWorld, v.vertex);
				o.normal = UnityObjectToWorldNormal(v.normal);
				UNITY_TRANSFER_FOG(o, o.pos);

				return o;
			}

			fixed4 frag(v2f i) : SV_Target
			{
				fixed4 col = tex2D(_MainTex,i.uv);
				half3 viewDir = normalize(UnityWorldSpaceViewDir(i.worldPos));

			#ifdef _SHOW_INNER_EFFECT
				half nv = saturate(dot(i.normal,viewDir));
				col.rgb =	SetInnerColor(col.rgb,nv,_InnerColor.rgb,_InnerPower);
			#else
				col = col * _Color;
			#endif

			#ifdef USING_DIRECTIONAL_LIGHT
				half3 lightDir = normalize(_WorldSpaceLightPos0.xyz);
			#else
				half3 lightDir = normalize(UnityWorldSpaceLightDir(i.worldPos));
			#endif


				return col;
			}

			ENDCG
		}
	}
}
