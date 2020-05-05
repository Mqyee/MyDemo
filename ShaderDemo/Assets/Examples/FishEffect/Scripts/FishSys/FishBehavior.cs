using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public enum FishState
{
    MOVE,     //正在按轨迹移动
    ESCAPE,     //正在散开
    GATHER,     //回到原来位置
    FOLLOW,    //跟随
}
public class FishBehavior : MonoBehaviour
{
    public FishGroupController fishgroup;
    public int fishGroupID;
    public int fishTypeID;
    public List<int> enermyTags = new List<int>();
    public string fishTag;
    public Vector3 offset;
    public bool isfullpath;
    public float mCurrentTime;
    public float delay;

    private SplineInterpolator splineI;
    private SplineController splineC;
    private List<SplineInterpolator.SplineNode> nodes;
    private string moveMode;
    private bool isRotate;
    int mCurrentIdx = 1;
    bool ismove = false;
    Vector3 lastEularAngles;
    float timer = 0;

    //New By roy状态改变相关
    GameObject PlayerGameObject;
    float disFromPlayer;
    List<FishBehavior> friends;
    public float changeStateDistance = 7;//改变状态距离(逃离，聚集)、
    //逃离
    public float escapeSpeed=7f;
    public float escapeTime = 10f;
    public float mCurrentEscapeTime = 0;
    //聚集
    private List<FishBehavior> allfriends;
    public float gatherSpeed=5;
    public float currentgatherSpeed = 0;
    public float gatherAddSpeed = 0.003f;
    public float gatherTurnAroundTime = 2f;
    public float mTurnArountTime = 0;

    public float followSpeed = 5f;
    public float followTime = 10f;
    public float mCurrentFollowTime = 0;
    public Vector3 originPos; //回到的原始位置
    public Vector3 orginVector3;//原始方向向量
    public Quaternion originRotate;//原始旋转四元数

    private Quaternion nextRotate;
    private Vector3 nextPos;
    private float timeparam;

    //每隔一段时间记录一下玩家的位置
    public Vector3 playerPos;
    public float getPlayerPosTime = 2f;
    public float currentGetTime;

    public float randomTime;
    public float randomCD;
    public float randomMinCd = 2f;
    public float randomMaxCd = 4f;
    public Vector3 randVelocity;
    public FishState curState = FishState.MOVE;
    
    void Start()
    {
        splineC = fishgroup.gameObject.GetComponent<SplineController>();
        splineI = fishgroup.gameObject.GetComponent<SplineInterpolator>();
        nodes = splineI.GetPoints();
        moveMode = splineI.GetState();
        isRotate = splineI.IsRotate();
        if (isfullpath == false) delay = Random.Range(0, delay);
    }
    void Update()
    {
        if (ismove == false && isfullpath == false)
            timer += Time.deltaTime;

        if (timer >= delay)
            ismove = true;

        if (ismove == false)
            return;
        
        //if(fishTag!=null) 
        //friends = GetFriends();

        curState =GetState();  //每帧去判定他的状态
        FreshPlayerPosByTime();   
        RandomVelocity();
        if (curState != FishState.MOVE)
            GetPosition();
        if (curState == FishState.MOVE)
            MoveByPathway();
        else if (curState == FishState.ESCAPE)
            Escape();    
        else if (curState == FishState.GATHER)
            Gather();
        else if (curState == FishState.FOLLOW)
            Follow();
    }
    

    public void MoveByPathway()
    {
        if (currentgatherSpeed != gatherSpeed)
            currentgatherSpeed = gatherSpeed;
        if (gatherTurnAroundTime != mTurnArountTime)
            mTurnArountTime = gatherTurnAroundTime;
        if (moveMode == "Reset" || moveMode == "Stopped" || nodes.Count < 4)
            return;
        mCurrentTime += Time.deltaTime;
        if (mCurrentTime >= nodes[mCurrentIdx + 1].Time)
        {
            if (mCurrentIdx < nodes.Count - 3)
            {
                mCurrentIdx++;
            }
            else
            {
                if (moveMode != "Loop")
                {
                    moveMode = "Stopped";
                    transform.position = nodes[nodes.Count - 2].Point;

                    if (isRotate)
                        transform.rotation = nodes[nodes.Count - 2].Rot;
                }
                else
                {
                    mCurrentIdx = 1;
                    mCurrentTime = 0;
                }
            }
        }

        if (moveMode != "Stopped")
        {
            timeparam = (mCurrentTime - nodes[mCurrentIdx].Time) / (nodes[mCurrentIdx + 1].Time - nodes[mCurrentIdx].Time);  //有可能会出现除以0的情况，所以下面要用IaNaN判断
            timeparam = MathUtils.Ease(timeparam, nodes[mCurrentIdx].EaseIO.x, nodes[mCurrentIdx].EaseIO.y);
            if (float.IsNaN(timeparam))
            {
                timeparam = 0.01f;
            }
            nextPos = GetHermiteInternal(mCurrentIdx, timeparam) + offset;
            if (!float.IsNaN(nextPos.x) && !float.IsNaN(nextPos.y) && !float.IsNaN(nextPos.z))
            {
                transform.position = nextPos;
            }
            
            if (isRotate)
            {
                nextRotate = GetSquad(mCurrentIdx, timeparam);
                transform.rotation = Quaternion.Slerp(transform.rotation, nextRotate, Time.deltaTime);
            }
        }
    }

    //把获取位置的剥离出来恒定计算
    public void GetPosition()
    {
       
        if (moveMode == "Reset" || moveMode == "Stopped" || nodes.Count < 4)
            return;
        mCurrentTime += Time.deltaTime;
        if (mCurrentTime >= nodes[mCurrentIdx + 1].Time)
        {
            if (mCurrentIdx < nodes.Count - 3)
            {
                mCurrentIdx++;
            }
            else
            {
                if (moveMode != "Loop")
                {
                    moveMode = "Stopped";
                    originPos = nodes[nodes.Count - 2].Point;
                    orginVector3 = originPos.normalized;
                    if (isRotate)
                        originRotate = nodes[nodes.Count - 2].Rot;
                }
                else
                {
                    mCurrentIdx = 1;
                    mCurrentTime = 0;
                }
            }
        }

        if (moveMode != "Stopped")
        {
            timeparam = (mCurrentTime - nodes[mCurrentIdx].Time) / (nodes[mCurrentIdx + 1].Time - nodes[mCurrentIdx].Time);
            timeparam = MathUtils.Ease(timeparam, nodes[mCurrentIdx].EaseIO.x, nodes[mCurrentIdx].EaseIO.y);
            if (float.IsNaN(timeparam))
            {
                timeparam = 0.01f;
            }
            nextPos = GetHermiteInternal(mCurrentIdx, timeparam) + offset;
            if (!float.IsNaN(nextPos.x) && !float.IsNaN(nextPos.y) && !float.IsNaN(nextPos.z))
            {
                originPos = nextPos;
            }

            if (isRotate)
            {
                nextRotate = GetSquad(mCurrentIdx, timeparam);
                originRotate = Quaternion.Slerp(originRotate, nextRotate, Time.deltaTime);
                
            }
        }
    }
    //逃逸
    public void Escape()
    {
        if (gatherTurnAroundTime != mTurnArountTime)
            mTurnArountTime = gatherTurnAroundTime;
        Vector3 escapeV3 = (transform.position - playerPos) + randVelocity;
        transform.rotation = Quaternion.Lerp(transform.rotation, Quaternion.LookRotation(escapeV3), 0.5f * Time.deltaTime);
        transform.position += transform.forward * escapeSpeed * Time.deltaTime; 
    }
    //聚集
    public void Gather()
    {
        currentgatherSpeed = currentgatherSpeed += gatherAddSpeed;
        transform.rotation = Quaternion.Lerp(transform.rotation, Quaternion.LookRotation(originPos-transform.position), 0.7f * Time.deltaTime);
        if (mTurnArountTime < 0)
        {
            transform.position = Vector3.MoveTowards(transform.position, originPos, currentgatherSpeed * 0.01f);
        }
        else
        {
            mTurnArountTime -= Time.deltaTime;
        }
        
    }
    //跟随
    public void Follow()
    {
        if (gatherTurnAroundTime != mTurnArountTime)
            mTurnArountTime = gatherTurnAroundTime;
        if (Vector3.Distance(transform.position, PlayerGameObject.transform.position) > 3f)
        {
            Vector3 lookV3 = (PlayerGameObject.transform.position - transform.position) ;
            transform.rotation = Quaternion.Lerp(transform.rotation, Quaternion.LookRotation(lookV3), 0.3f * Time.deltaTime);
            transform.position += transform.forward * followSpeed * Time.deltaTime;
        }
        else
        {
            transform.rotation = Quaternion.Lerp(transform.rotation, Quaternion.LookRotation(transform.position - playerPos), 0.2f * Time.deltaTime);
            transform.position += transform.forward * followSpeed * Time.deltaTime;
        }
        
    }

    public Vector3 GetHermiteInternal(int idxFirstPoint, float t)
    {
        float t2 = t * t;
        float t3 = t2 * t;

        Vector3 P0 = nodes[idxFirstPoint - 1].Point;
        Vector3 P1 = nodes[idxFirstPoint].Point;
        Vector3 P2 = nodes[idxFirstPoint + 1].Point;
        Vector3 P3 = nodes[idxFirstPoint + 2].Point;

        float tension = 0.5f;

        Vector3 T1 = tension * (P2 - P0);
        Vector3 T2 = tension * (P3 - P1);

        float Blend1 = 2 * t3 - 3 * t2 + 1;
        float Blend2 = -2 * t3 + 3 * t2;
        float Blend3 = t3 - 2 * t2 + t;
        float Blend4 = t3 - t2;

        return Blend1 * P1 + Blend2 * P2 + Blend3 * T1 + Blend4 * T2;
    }
    Quaternion GetSquad(int idxFirstPoint, float t)
    {
        Quaternion Q0 = nodes[idxFirstPoint - 1].Rot;
        Quaternion Q1 = nodes[idxFirstPoint].Rot;
        Quaternion Q2 = nodes[idxFirstPoint + 1].Rot;
        Quaternion Q3 = nodes[idxFirstPoint + 2].Rot;

        Quaternion T1 = MathUtils.GetSquadIntermediate(Q0, Q1, Q2);
        Quaternion T2 = MathUtils.GetSquadIntermediate(Q1, Q2, Q3);

        return MathUtils.GetQuatSquad(t, Q1, Q2, T1, T2);
    }


    /// <summary>
    /// 改变状态
    /// 如果玩家和鱼的位置小于changeStateDistance则状态就会改变
    /// 根据标签表现不同状态
    /// 如果超过时间且与玩家距离大于changeStateDistance则回到聚集状态gather
    /// </summary>
    /// <returns></returns>
    FishState GetState()
    {
        PlayerGameObject = GameObject.FindGameObjectWithTag("Player");
        if (PlayerGameObject == null ) return FishState.MOVE;

        disFromPlayer = Vector3.Distance(PlayerGameObject.transform.position, this.transform.position);
        if (disFromPlayer <= changeStateDistance)
        {
            if (this.fishTag == "SmallFish")
            {
                mCurrentEscapeTime = escapeTime;
                return FishState.ESCAPE;
            }
            else if (this.fishTag == "BigFish")
            {
                mCurrentFollowTime = followTime;
                return FishState.FOLLOW;
            }
            else
            {
                return FishState.MOVE;
            }
           
        }
        else
        {
            if ( mCurrentEscapeTime > 0 && this.fishTag == "SmallFish")
            {
                mCurrentEscapeTime -= Time.deltaTime;;
                return FishState.ESCAPE;
            }
            else if (mCurrentFollowTime > 0 && this.fishTag == "BigFish")
            {
                mCurrentFollowTime -= Time.deltaTime; ;
                return FishState.FOLLOW;
            }
            else
            {
                if (curState != FishState.MOVE)
                {
                    float disFromOrigin = Vector3.Distance(originPos, this.transform.position);
                    if (disFromOrigin <= 0.05)
                    {
                        return FishState.MOVE;
                    }
                    else
                    {
                        return FishState.GATHER;
                    }
                }
                else
                {
                    return FishState.MOVE;
                }
                
            }
           
        }
    }
    //每隔多少秒获取一下玩家的位置
    void FreshPlayerPosByTime()
    {
        currentGetTime -= Time.deltaTime;
        if (currentGetTime < 0)
        {
            currentGetTime = getPlayerPosTime;
            if (PlayerGameObject != null)
                playerPos = PlayerGameObject.transform.position;
        }
        
    }
    ////////////////////////////////////////开始一系列的向量///////////////////////////////////////////

    Vector3 EscapeVector()
    {
        return playerPos-transform.position;
    }

    
    Vector3 KeepFriendsDisVelocity(List<FishBehavior> friends)
    {
        float dis = 999;
        FishBehavior yu = null;
        foreach (var item in friends)
        {
            float d = Vector3.Distance(transform.position, item.transform.position);
            if (d < dis)
            {
                dis = d;
                yu = item;
            }
        }
        if (yu != null)
        {
            return (yu.transform.position - transform.position).normalized  * 30;
        }
        else
        {
            return Vector3.zero;
        }
    }

    Vector3 KeepFriendsVelocity(List<FishBehavior> friends)
    {
        Vector3 friendsVel = Vector3.zero;
        if (friends.Count == 0) return friendsVel;
        foreach (var item in friends)
        {
            friendsVel += item.transform.forward;
        }
        friendsVel /= friends.Count;
        return friendsVel.normalized * 30;
    }

    

    void RandomVelocity()
    {
        randomTime -= Time.deltaTime;
        if (randomTime <= 0)
        {
            randomTime = randomCD;
            randomCD = Random.Range(randomMinCd, randomMaxCd);
            randVelocity = new Vector3(Random.Range(-1f, 1f), Random.Range(-0.3f, 0.3f), Random.Range(-1f, 1f)).normalized * 40;
        }
    }


}