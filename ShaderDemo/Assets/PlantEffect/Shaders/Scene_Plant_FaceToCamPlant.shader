Shader "Scene/Plant/FaceToCamPlant" 
{
	Properties 
	{
		_MainTex ("Base (RGB)", 2D) = "white" {}
		_Dir("Direction", vector) = (1,0,0,0)
		_Power("_Power",float) = 1.0
		_TimeOff("_TimeOffset",float)=0.0
		_Cutoff("Cut Off", Range(0.01, 1)) = 0.5
		_VerticalBillboarding("Vertical Restraints", Range(0,1)) = 1
		_ActorPos("Actor Position", vector) = (0, 0, 0, 0)
		[HideInInspector]_MoveChange("_MoveChange", float) = 0.0
		_stress("Stress",float) = 1
	}

	SubShader 
	{
		Tags {"Queue"="AlphaTest" "IgnoreProjector"="True" "RenderType"="TransparentCutout" "DisableBatching" = "false"}
		
		LOD 200
		Blend SrcAlpha OneMinusSrcAlpha

		Pass
		{
			Tags {"LightMode" = "ForwardBase"}

			LOD 200

			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#include "UnityCG.cginc"
			#include "Lighting.cginc"
			#pragma multi_compile_instancing
			#pragma multi_compile_fog
			#pragma exclude_renderers ps3 xbox360 flash xboxone ps4 psp2
			#define UNITY_INSTANCED_LOD_FADE
			#define UNITY_INSTANCED_SH
			#define UNITY_INSTANCED_LIGHTMAPSTS

			sampler2D _MainTex;
			float4 _MainTex_ST;
			float3 _Dir;
			half _Power;
			half _TimeOff;
			float _Cutoff;
			float _VerticalBillboarding;
			uniform float4 _ActorPos;
			float _MoveChange;
			float _stress;

			struct v2f
			{
				float4 pos		: SV_POSITION;
				float2 uv		: TEXCOORD0;
				half3 ambient	: TEXCOORD1;
				float3 worldPos : TEXCOORD2;
				float3 viewDir  : TEXCOORD3;
				UNITY_FOG_COORDS(4)
				UNITY_VERTEX_INPUT_INSTANCE_ID
			};

			float4 _BufferWave[1];

			v2f vert(appdata_full v)
			{
				UNITY_SETUP_INSTANCE_ID(v);

				v2f o;
				UNITY_INITIALIZE_OUTPUT(v2f, o);
				UNITY_TRANSFER_INSTANCE_ID(v, o);
				o.uv = v.texcoord;
				float3 objVertex = mul(unity_ObjectToWorld, v.vertex).xyz;//先将顶点转换到世界空间
				float3 vertexVec = objVertex.xyz - _ActorPos.xyz;//pos到顶点的方向向量
				float distance = sqrt(vertexVec.x * vertexVec.x + vertexVec.z * vertexVec.z);//距离因子，只控制了x & z，如果需要可以把 y 写进去                      + vertexVec.y * vertexVec. 0
				half pp = step(distance, 1);
				distance *= pp;
				float y = v.vertex.y;
				float3 moveOffset = normalize(vertexVec)*distance * 3;
				float3 offset = clamp(moveOffset, -5, 5);
				offset = mul(unity_WorldToObject, offset)*(0.5-_MoveChange);
				v.vertex.xyz += offset*v.texcoord.y*_stress;
				v.vertex.y = y;

				float3 center = float3(0,0,0);
				float3 viewer = mul(unity_WorldToObject,float4(_WorldSpaceCameraPos,1));
				float3 normalDir = viewer - center;
				normalDir.y = normalDir.y * _VerticalBillboarding;
				normalDir = normalize(normalDir);

				float3 upDir = abs(normalDir.y) > 0.999 ?  float3(0,0,1) : float3(0,1,0);
				float3 rightDir = normalize(cross(upDir,normalDir));
				upDir = normalize(cross(normalDir,rightDir));

				v.vertex.xyz += _Dir * _Power*sin(_Time.y+_TimeOff)*v.texcoord.y;
				float3 centerOffs = v.vertex.xyz - center;
				float3 localPos = center + rightDir * centerOffs.x + upDir * centerOffs.y + normalDir * centerOffs.z; 

				o.worldPos = mul(unity_ObjectToWorld, float4(localPos, 1));

				float3 delta = o.worldPos.xyz - _BufferWave[0].xyz;
				float2 ndelta = normalize(delta.xz);
				localPos.xz += exp2(-length(delta)) * ndelta *_BufferWave[0].w * v.texcoord.y; //dot(ndelta, _BufferWave[i].zw);

				o.pos = UnityObjectToClipPos(float4(localPos,1));
			
				o.uv = TRANSFORM_TEX(v.texcoord, _MainTex);
				o.ambient = ShadeSH9(float4(UnityObjectToWorldNormal(v.normal), 1.0));

				o.viewDir = normalize(UnityWorldSpaceViewDir(o.worldPos));

				UNITY_TRANSFER_FOG(o, o.pos);

				return o;
			}

			fixed4 frag(v2f i):SV_Target
			{
				UNITY_SETUP_INSTANCE_ID(i);

				half4 c = tex2D (_MainTex, i.uv);
				c.rgb *= saturate(i.ambient + 0.25 * _LightColor0.rgb);
				clip (c.a - _Cutoff);

				return  c;
			}

			ENDCG
		}
	} 

	FallBack Off
}
