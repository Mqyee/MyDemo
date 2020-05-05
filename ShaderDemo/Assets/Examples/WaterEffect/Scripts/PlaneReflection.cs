using System;
using System.Collections.Generic;
using UnityEngine;

[ExecuteInEditMode]
[RequireComponent(typeof(Renderer))]
public class PlaneReflection : MonoBehaviour
{    
    public LayerMask reflectionMask = 0;
    public CameraClearFlags clearFlags = CameraClearFlags.Color;
    public Color clearColor = new Color(0.5f, 0.75f, 1.0f, 1.0f);
    public float clipPlaneOffset = 0.05f;
    public bool refreshReflection = false;
    public RenderingPath path = RenderingPath.Forward;

    private Camera reflectCamera = null;
    private Vector4 clipPlane = Vector4.zero;
    //private int _ReflectionTex = -1;
    //private int _Reflection = -1;
    private readonly string _ReflectionTex = "_ReflectionTex";
    private readonly string _Reflection = "_Reflection";

    private int dropLayer = 0;
    private List<string> dropLayerNames;
    private Material waterMaterial;
    private bool renderReflection = true;
    private uint sceneID = 0;

    private void Awake()
    {
        //dropLayerNames = new List<string>
        //{
        //    LAYER.WATER,
        //    LAYER.UI_HERO,
        //    LAYER.HERO,
        //    LAYER.PLAYER,
        //    LAYER.NPC,
        //    LAYER.MONSTER,
        //    LAYER.Hair,
        //    LAYER.Hero_Hair,
        //    LAYER.Player_Effect,
        //    LAYER.FOLLOWER,
        //    LAYER.Grab,
        //    LAYER.PET
        //};

        dropLayer = LayerMask.GetMask(dropLayerNames.ToArray());

        gameObject.layer = LayerMask.NameToLayer("Water");
        reflectionMask = ~dropLayer;

        //Messenger.AddListener<object, object>(MSG_DEFINE.MSG_QUALITY_SETTING_CHANGE, QualitySettingChange);
    }

    private void Start()
    {
        waterMaterial = GetComponent<Renderer>().sharedMaterial;
        if (waterMaterial == null)
            enabled = false;
    }

    void OnEnable()
    {
        dropLayer = LayerMask.GetMask(dropLayerNames.ToArray());

        //暂时用名字直接SetTexture，免得多个水面反射出现bug
        //_ReflectionTex = Shader.PropertyToID("_ReflectionTex");
        //_Reflection = Shader.PropertyToID("_Reflection");
    }

#if UNITY_EDITOR
    private void OnValidate()
    {
        UnityEditor.SceneView.RepaintAll();
    }
#endif

    private void OnDisable()
    {
        Destroy();
    }

    void OnApplicationQuit()
    {
        Destroy();
    }

    private void OnDestroy()
    {
        Destroy();
        //Messenger.RemoveListener<object, object>(MSG_DEFINE.MSG_QUALITY_SETTING_CHANGE, QualitySettingChange);
    }

    private bool CheckSupport()
    {
        bool isSupport = true;

        if (waterMaterial == null || waterMaterial.shader == null)
            isSupport = false;

        return isSupport;
    }

    private void Destroy()
    {
        if (reflectCamera != null)
        {
            RenderTexture rt = reflectCamera.targetTexture;
            reflectCamera.targetTexture = null;
            if(waterMaterial != null && waterMaterial.HasProperty(_ReflectionTex))
                waterMaterial.SetTexture(_ReflectionTex, null);
            rt.Release();
            DestroyImmediate(rt);
#if UNITY_EDITOR
            DestroyImmediate(reflectCamera.gameObject);
            Caching.ClearCache();
#else
            Destroy(reflectCamera.gameObject);
#endif
            reflectCamera = null;
            rt = null;
        }
    }

    void CreateReflectCamera(Camera camera)
    {
        if (reflectCamera != null) return;

        string str = gameObject.name + "Reflection" + camera.name;
        GameObject go = new GameObject(str, typeof(Camera))
        {
            hideFlags = HideFlags.DontSave | HideFlags.NotEditable
        };

        go.transform.parent = transform;

        reflectCamera = go.GetComponent<Camera>();
        reflectCamera.depthTextureMode = DepthTextureMode.None;
        reflectCamera.renderingPath = RenderingPath.Forward;
        reflectCamera.allowHDR = false;
        reflectCamera.allowMSAA = false;
        reflectCamera.useOcclusionCulling = false;
        reflectCamera.backgroundColor = clearColor;
        reflectCamera.clearFlags = clearFlags;
        reflectCamera.cullingMask = reflectionMask & ~LayerMask.GetMask("Water", "UI");
        reflectCamera.useOcclusionCulling = false;
        reflectCamera.enabled = false;

        reflectCamera.farClipPlane = camera.farClipPlane;
        reflectCamera.nearClipPlane = camera.nearClipPlane;
        reflectCamera.orthographic = camera.orthographic;
        reflectCamera.fieldOfView = camera.fieldOfView;
        reflectCamera.aspect = camera.aspect;
        reflectCamera.orthographicSize = camera.orthographicSize;
    }

    void CreateRenderTexture(Camera camera)
    {
        if (!reflectCamera.targetTexture)
        {
            RenderTextureFormat format = RenderTextureFormat.Default;

            if (SystemInfo.SupportsRenderTextureFormat(RenderTextureFormat.RGB111110Float))
                format = RenderTextureFormat.RGB111110Float;

            RenderTexture rt = new RenderTexture(camera.pixelWidth, camera.pixelHeight, 16, format)
            {
                name = "_ReflectionTex",
                hideFlags = HideFlags.DontSave
            };
            rt.Create();
            reflectCamera.targetTexture = rt;            
        }
    }

    void RenderReflection()
    {
        GL.invertCulling = true;
        Vector3 n = transform.up;
        float d = -Vector3.Dot(n, transform.position) - clipPlaneOffset;
        Matrix4x4 reflectMatrix = CalculateReflectionMatrix(n, d);
        reflectCamera.worldToCameraMatrix = Camera.current.worldToCameraMatrix * reflectMatrix;
        clipPlane.Set(n.x, n.y, n.z, d);
        clipPlane = reflectCamera.cameraToWorldMatrix.transpose * clipPlane;
        reflectCamera.projectionMatrix = reflectCamera.CalculateObliqueMatrix(clipPlane);
        reflectCamera.clearFlags = clearFlags;
        reflectCamera.renderingPath = path;
        reflectCamera.cullingMask = reflectionMask & ~dropLayer;
        reflectCamera.Render();
        GL.invertCulling = false;
    }

    private void OnWillRenderObject()
    {
        if (waterMaterial == null)
            return;

        if (refreshReflection)
        {
            Destroy();
            refreshReflection = false;
        }

        //if(SceneMgr.Instance != null)
        //    sceneID = SceneMgr.Instance.SceneId;

        //美术制作过程中根据材质球控制是否开启实时反射
//#if UNITY_EDITOR
        if (waterMaterial.HasProperty(_Reflection))
        {
            renderReflection = waterMaterial.GetFloat(_Reflection) == 1 ? true : false;
        }
        else
        {
            renderReflection = false;

            if(Application.isPlaying)
            {
                enabled = false;
            }
        }
//#endif

        if (renderReflection)
        {
            CreateReflectCamera(Camera.current);
            CreateRenderTexture(Camera.current);

            if (reflectCamera != null && CheckSupport() && reflectCamera.targetTexture != null)
            {
                RenderReflection();
                if(waterMaterial.HasProperty(_Reflection))
                    waterMaterial.SetFloat(_Reflection, 1);
                if(waterMaterial.HasProperty(_ReflectionTex))
                    waterMaterial.SetTexture(_ReflectionTex, reflectCamera.targetTexture);
            }
        }
        else
        {
            if (waterMaterial.HasProperty(_Reflection))
                if(waterMaterial.GetFloat(_Reflection) != 0)
                    waterMaterial.SetFloat(_Reflection, 0);
            Destroy();
        }
    }

    private void QualitySettingChange(object lastVal, object curVal)
    {
        if (!CheckSupport()) return;

        int curQSVal = Convert.ToInt32(curVal);

        //dataconfig.QualitySetting curQSInfo = QualitySettingMgr.GetQualitySetInfo(curQSVal);

        //water开到2级才有实时反射
        //shaderlod 400 实时反射 折射 高光
        //shaderlod 300 cube反射 高光
        //shaderlod 200 cube反射
        //目前僅家園的水執行此劃分，其他場景無最高品質實時反射
        //if (!curQSInfo.Invalid() && (sceneID == 221101 || sceneID == 221100 || sceneID == 221104))
        //    renderReflection = curQSInfo.water == 2 ? true : false;
        //else
        //    renderReflection = false;

        //实时反射全部关闭
        renderReflection = false;
    }

    Matrix4x4 CalculateReflectionMatrix(Vector3 n, float d)
    {
        Matrix4x4 reflectionMat;
        reflectionMat.m00 = (1f - 2f * n.x * n.x);
        reflectionMat.m01 = (-2f * n.x * n.y);
        reflectionMat.m02 = (-2f * n.x * n.z);
        reflectionMat.m03 = (-2f * d * n.x);

        reflectionMat.m10 = (-2f * n.y * n.x);
        reflectionMat.m11 = (1f - 2f * n.y * n.y);
        reflectionMat.m12 = (-2f * n.y * n.z);
        reflectionMat.m13 = (-2f * d * n.y);

        reflectionMat.m20 = (-2f * n.z * n.x);
        reflectionMat.m21 = (-2f * n.z * n.y);
        reflectionMat.m22 = (1f - 2f * n.z * n.z);
        reflectionMat.m23 = (-2f * d * n.z);

        reflectionMat.m30 = 0;
        reflectionMat.m31 = 0;
        reflectionMat.m32 = 0;
        reflectionMat.m33 = 1;

        return reflectionMat;
    }
}
