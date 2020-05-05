using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using AnimationInstancing;
public class FishGroupController : MonoBehaviour
{
    public GameObject fishPrefab;
    public int fishGroupID;
    public int fishTypeID;
    public List<int> enermyTags = new List<int>() ;
    //public string playerTag;
    public string fishTag;
    public int fishNum = 10;
    public bool fullPathway = true;
    public int createRange = 0;
    public Vector3 offsetRange ;     //偏移轨道的范围
    [Space]
    public float mat_ShakeSpeedRange = 0.5f;  //鱼shader摆动速度范围
    public float mat_ShakeFrequenceRange = 3;  //鱼shader摆动频率范围
    public float delayMove = 0;
    private List<Vector3> posList;
    private List<FishBehavior> fishs = new List<FishBehavior>();

    //控制鱼运动相关参数
    public float changeStateDistance = 7;//改变状态距离(逃离，聚集)、
    //逃离
    public float escapeSpeed = 7f;
    public float escapeTime = 10f;
    //聚集
    public float gatherSpeed = 5;
    public float gatherAddSpeed = 0.003f;
    public float gatherTurnAroundTime = 2f;

    public float followSpeed = 5f;
    public float followTime = 10f;
    public bool isShowEffect = false;
    private List<Renderer> renders = new List<Renderer>();
    private MaterialPropertyBlock prop;
    private List<SplineController.posData> poslist = new List<SplineController.posData>();

    void Start()
    {
        gameObject.GetComponent<SplineController>().enabled = true;
        prop = new MaterialPropertyBlock();
        poslist = gameObject.GetComponent<SplineController>().posList;
        CreateFishGroup(fishNum);
    }

    public void CreateFishGroup(int fish_num)
    {
        //非闭合情况下，可调整鱼群的出生点占轨迹的比例 
        int rate = 0;
        if (createRange != 0 && fullPathway == false)
        {
            if (createRange > poslist.Count) createRange = poslist.Count;
            rate = poslist.Count / createRange;
        }
        for (int i = 0; i < fish_num; i++)
        {
            FishBehavior fish = GameObject.Instantiate(fishPrefab).AddComponent<FishBehavior>();
            Vector3 val = new Vector3(Random.Range(-offsetRange.x, offsetRange.x), Random.Range(-offsetRange.y, offsetRange.y), Random.Range(-offsetRange.z, offsetRange.z));
            if (fullPathway == true)
            {
                int index = Random.Range(0, poslist.Count - 1);
                Vector3 pos = poslist[index].pos + val;
                fish.transform.position = pos;
                fish.transform.SetParent(transform);
                fish.mCurrentTime = poslist[index].Time;
            }
            else
            {
                int index = Random.Range(0, rate);
                Vector3 pos = poslist[index].pos + val;
                fish.transform.position = pos;
                fish.transform.SetParent(transform);
                fish.mCurrentTime = poslist[index].Time;
            }
            fish.isfullpath = fullPathway;
            fish.offset = val;
            fish.fishGroupID = fishGroupID;
            fish.fishTypeID = fishTypeID;
            fish.enermyTags = enermyTags;
            fish.fishTag = fishTag;
            //fish.playerTag = playerTag;
            fish.fishgroup = this;
            fish.delay = delayMove;
            fish.changeStateDistance = changeStateDistance;//改变状态距离(逃离，聚集)
            //逃离                                                                                                                        
            fish.escapeSpeed = escapeSpeed;
            fish.escapeTime = escapeTime;
            //聚集
            fish.gatherSpeed = gatherSpeed;
            fish.gatherAddSpeed = gatherAddSpeed;
            fish.gatherTurnAroundTime = gatherTurnAroundTime;

            fish.followSpeed = followSpeed;
            fish.followTime = followTime;
            fishs.Add(fish);
            if (fishPrefab.name.EndsWith("_gpu_ins"))
            {
                Renderer render = fish.GetComponentInChildren<Renderer>(true);
                if (render != null)
                {
                    renders.Add(render);
                    SetMatDatas(render);
                }
            }

        }
         if (fishPrefab.name.EndsWith("_anim_ins"))
        {
            if (isShowEffect == true)
                AnimationInstancingMgr.Instance.SetInnerEffectState(fishs[0].gameObject, 1);
            else
                AnimationInstancingMgr.Instance.SetInnerEffectState(fishs[0].gameObject, 0);
        }
    }

    void SetMatDatas(Renderer render)
    {
            render.GetPropertyBlock(prop);
            prop.SetFloat("_Speed", GetRandom(render.sharedMaterial.GetFloat("_Speed"), mat_ShakeSpeedRange));
            prop.SetFloat("_Frequence", GetRandom(render.sharedMaterial.GetFloat("_Frequence"), mat_ShakeFrequenceRange));
        if (isShowEffect == true)
            prop.SetFloat("_IsShowInner", 1);
        else
            prop.SetFloat("_IsShowInner", 0);

        render.SetPropertyBlock(prop);
    }
    float GetRandom(float value, float limit = 0)
    {
        return Random.Range(value - limit, value + limit);
    }

    public void SetFIshInnerEffectState(bool state)
    {
        isShowEffect = state;
        if (fishPrefab.name.EndsWith("_gpu_ins"))
        {
            for (int i = 0; i < renders.Count; i++)
            {
                renders[i].GetPropertyBlock(prop);
                if (state == true)
                    prop.SetFloat("_IsShowInner", 1);
                else
                    prop.SetFloat("_IsShowInner", 0);
                renders[i].SetPropertyBlock(prop);
            }
        }
        else if (fishPrefab.name.EndsWith("_anim_ins"))
        {
            if (isShowEffect == true)
                AnimationInstancingMgr.Instance.SetInnerEffectState(fishs[0].gameObject, 1);
            else
                AnimationInstancingMgr.Instance.SetInnerEffectState(fishs[0].gameObject, 0);
        }
    }

    public void OnUninit()
    {
        for(int i = 0;i < fishs.Count;i++)
        {
            Destroy(fishs[i].gameObject);
        }
        fishs.Clear();
        renders.Clear();
    }
}

