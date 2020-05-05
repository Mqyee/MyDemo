Shader "Fish/GPUInstancingFish"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
		_Speed("摆动速度",Range(0,50)) = 0
		_MoveOffset("摆动偏移",Range(0,10)) = 0
		_Frequence("摆动频率",Range(0,50)) = 0
		_HeadLength("头部固定长度",float) = 0
		_HeadRotate("头部旋转角度",range(0,50)) = 0
		[Toggle(_ROTATE_BODY)]_Rotate0("脊椎旋转",float) = 0
		_RoaScale("脊椎旋转幅度",Range(0,2)) = 0
		_RoaFrequence("脊椎旋转频率",Range(0,50)) = 0
		[Toggle(_ROTATE_LEFT_RIGHT)]_Rotate1("左右摆动",float) = 1
		[Toggle(_ROTATE_UP_DOWN)]_Rotate2("上下摆动",float) = 0
		[Toggle(_SHOW_INNER_EFFECT)]_ShowInnerEffect("内发光",float) = 0
		[HDR] _Color ("Color", Color) = (1, 1, 1, 1)
		[HDR]_InnerColor("InnerColor",Color) = (1,1,1,1)
		_InnerPower("InnerPower",Range(1,10)) = 8
		_IsShowInner("IsShowInner",Range(0,1)) = 0
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" "Queue"="Transparent-10"}
		
		LOD 200

		Blend SrcAlpha OneMinusSrcAlpha

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
			#pragma multi_compile_instancing
			#pragma multi_compile __ _ROTATE_BODY
			#pragma multi_compile __ _ROTATE_LEFT_RIGHT
			#pragma multi_compile __ _ROTATE_UP_DOWN
			#pragma multi_compile __ FOG_LINEAR	
			#pragma multi_compile	__ _SHOW_INNER_EFFECT
            #include "UnityCG.cginc"
			#include "Lighting.cginc"

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 pos : SV_POSITION;
				float3 worldPos : TEXCOORD1;
				float3 normal : TEXCOORD2;
				UNITY_FOG_COORDS(3)

				UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;
			sampler2D _NormalMap;
			float _RoaScale;
			float _RoaFrequence;
			float _MoveOffset;
			float _HeadLength;
			float _HeadRotate;
			float4 _Color;
			float4 _InnerColor;
			half _InnerPower;
			UNITY_INSTANCING_BUFFER_START(Props)
				UNITY_DEFINE_INSTANCED_PROP(float, _Speed)
				UNITY_DEFINE_INSTANCED_PROP(float, _Frequence)
				UNITY_DEFINE_INSTANCED_PROP(float,_IsShowInner)
			UNITY_INSTANCING_BUFFER_END(Props)

			float3x3 AngleAxis3x3(float angle, float3 axis)
			{
				float c, s;
				sincos(angle, s, c);
 
				float t = 1 - c;
				float x = axis.x;
				float y = axis.y;
				float z = axis.z;
 
				return float3x3(
					t * x * x + c, t * x * y - s * z, t * x * z + s * y,
					t * x * y + s * z, t * y * y + c, t * y * z - s * x,
					t * x * z - s * y, t * y * z + s * x, t * z * z + c
				);
			}

			float4 vertexmove(float3 vertex)
			{
				float time = _Time.y * UNITY_ACCESS_INSTANCED_PROP(Props,_Speed);

				//脊椎旋转
				#ifdef _ROTATE_BODY
					float warp = sin(time + vertex.x *_RoaFrequence) * _RoaScale ;
					float3x3 roaMat = AngleAxis3x3(warp,float3(1,0,0));
					vertex = lerp(vertex,mul(roaMat,vertex),1);
				#endif

				//左右or上下摆动
				float move_offset = cos( time) * _MoveOffset;
				float headfixed = smoothstep(vertex.x,vertex.x + _HeadLength,_HeadRotate);
				float warp1 = sin(time + vertex.x *UNITY_ACCESS_INSTANCED_PROP(Props,_Frequence));
				#ifdef _ROTATE_LEFT_RIGHT
					float3x3 roaMat1 = AngleAxis3x3(warp1,float3(0,0,1));
					vertex.y -= move_offset; 
				#else
					float3x3 roaMat1 = AngleAxis3x3(warp1,float3(0,1,0));
					vertex.z -= move_offset; 
				#endif
				vertex = lerp(vertex,mul(roaMat1,vertex),headfixed);

				return float4(vertex,1.0);
			}

            v2f vert (appdata_base v)
            {
                v2f o;
				UNITY_INITIALIZE_OUTPUT(v2f,o);
				UNITY_SETUP_INSTANCE_ID(v);
                UNITY_TRANSFER_INSTANCE_ID(v, o);

				v.vertex = vertexmove(v.vertex);
                o.pos = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.texcoord, _MainTex);
				o.worldPos = mul(unity_ObjectToWorld, v.vertex);
				o.normal = UnityObjectToWorldNormal(v.normal);
				UNITY_TRANSFER_FOG(o, o.pos);

                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
				fixed4 col = tex2D(_MainTex,i.uv);
				half3 viewDir = normalize(UnityWorldSpaceViewDir(i.worldPos));
			#ifdef _SHOW_INNER_EFFECT
				half nv = saturate(dot(i.normal,viewDir));
				half3 innerCol = _InnerColor.rgb *  pow((1- nv)*UNITY_ACCESS_INSTANCED_PROP(Props,_IsShowInner),_InnerPower) * (cos(_Time.z*2 ) + 1);
				col.rgb += innerCol;
			#else
				col = col * _Color;
			#endif
			#ifndef USING_DIRECTIONAL_LIGHT
				half3 lightDir = normalize(UnityWorldSpaceLightDir(i.worldPos));
			#else
				half3 lightDir = _WorldSpaceLightPos0.xyz;
			#endif
			UNITY_APPLY_FOG(i.fogCoord,col);

				 return col;
            }
            ENDCG
        }
    }
}

			