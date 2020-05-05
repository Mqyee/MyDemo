using UnityEngine;
using System.Collections;
using System.Collections.Generic;

public enum eOrientationMode { NODE = 0, TANGENT }

[AddComponentMenu("Splines/Spline Controller")]
[RequireComponent(typeof(SplineInterpolator))]
public class SplineController : MonoBehaviour
{
	public GameObject SplineRoot;
	public float Duration = 10;
    public float smooth = 50;
	public eOrientationMode OrientationMode = eOrientationMode.TANGENT;
	public eWrapMode WrapMode = eWrapMode.LOOP;
	public bool AutoStart = true;
	public bool AutoClose = true;
	public bool HideOnExecute = true;
    public List<posData> posList = new List<posData>();


	SplineInterpolator mSplineInterp;
	Transform[] mTransforms;

    public struct posData
    {
       public Vector3 pos;
       public float Time;
    }

	void OnDrawGizmos()
	{
		Transform[] trans = GetTransforms();
		if (trans.Length < 2)
			return;

		SplineInterpolator interp = GetComponent(typeof(SplineInterpolator)) as SplineInterpolator;
		SetupSplineInterpolator(interp, trans);
		interp.StartInterpolation(null, false, WrapMode);

		Vector3 prevPos = trans[0].position;
		for (int c = 1; c <= 50; c++)
		{
            float currTime = c * Duration / smooth;
			Vector3 currPos = interp.GetHermiteAtTime(currTime);
			float mag = (currPos-prevPos).magnitude * 2;
			Gizmos.color = new Color(mag, 0, 0, 1);
			Gizmos.DrawLine(prevPos, currPos);
			prevPos = currPos;
		}
	}

    void Awake()
    {
        enabled = false;
    }

    void OnEnable()
    {
        mSplineInterp = GetComponent(typeof(SplineInterpolator)) as SplineInterpolator;

        mTransforms = GetTransforms();

        if (HideOnExecute)
            DisableTransforms();

        if (AutoStart)
            FollowSpline();

        SavePathwaPos();
    }

    void FollowSpline()
    {
        if (mTransforms.Length > 0)
        {
            SetupSplineInterpolator(mSplineInterp, mTransforms);
            mSplineInterp.StartInterpolation(null, true, WrapMode);
        }
    }

    void SavePathwaPos()
    {
        for (int c = 1; c <= 50; c++)
        {
            posData data = new posData();
            float currTime = c * Duration / smooth;
            Vector3 currPos = mSplineInterp.GetHermiteAtTime(currTime);
            data.pos = currPos;
            data.Time = currTime;
            posList.Add(data);
        }
    }

    void SetupSplineInterpolator(SplineInterpolator interp, Transform[] trans)
	{
        interp.Reset();

        float step = (AutoClose) ? Duration / trans.Length :
			Duration / (trans.Length - 1);

		int c;
		for (c = 0; c < trans.Length; c++)
		{
			if (OrientationMode == eOrientationMode.NODE)
			{
				interp.AddPoint(trans[c].position, trans[c].rotation, step * c, new Vector2(0, 1));
			}
			else if (OrientationMode == eOrientationMode.TANGENT)
			{
				Quaternion rot;
				if (c != trans.Length - 1)
					rot = Quaternion.LookRotation(trans[c + 1].position - trans[c].position, trans[c].up);
				else if (AutoClose)
					rot = Quaternion.LookRotation(trans[0].position - trans[c].position, trans[c].up);
				else
					rot = trans[c].rotation;

				interp.AddPoint(trans[c].position, rot, step * c, new Vector2(0, 1));
			}
		}

		if (AutoClose)
			interp.SetAutoCloseMode(step * c);
	}


	/// <summary>
	/// Returns children transforms, sorted by name.
	/// </summary>
	Transform[] GetTransforms()
	{
		if (SplineRoot != null)
		{
			List<Component> components = new List<Component>(SplineRoot.GetComponentsInChildren(typeof(Transform)));
			List<Transform> transforms = components.ConvertAll(c => (Transform)c);

			transforms.Remove(SplineRoot.transform);
			transforms.Sort(delegate(Transform a, Transform b)
			{
				return a.name.CompareTo(b.name);
			});

			return transforms.ToArray();
		}

		return null;
	}

	/// <summary>
	/// Disables the spline objects, we don't need them outside design-time.
	/// </summary>
	void DisableTransforms()
	{
		if (SplineRoot != null)
		{
			SplineRoot.SetActive(false);
		}
	}



}