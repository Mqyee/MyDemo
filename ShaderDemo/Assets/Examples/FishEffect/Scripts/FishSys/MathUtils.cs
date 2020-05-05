using UnityEngine;
using System.Collections;
using System.Collections.Generic;

public class MathUtils
{
	public static float GetQuatLength(Quaternion q)
	{
		return Mathf.Sqrt(q.x * q.x + q.y * q.y + q.z * q.z + q.w * q.w);
	}

	public static Quaternion GetQuatConjugate(Quaternion q)
	{
		return new Quaternion(-q.x, -q.y, -q.z, q.w);
	}

	/// <summary>
	/// Logarithm of a unit quaternion. The result is not necessary a unit quaternion.
	/// </summary>
	public static Quaternion GetQuatLog(Quaternion q)
	{
		Quaternion res = q;
		res.w = 0;

		if (Mathf.Abs(q.w) < 1.0f)
		{
			float theta = Mathf.Acos(q.w);
			float sin_theta = Mathf.Sin(theta);

			if (Mathf.Abs(sin_theta) > 0.0001)
			{
				float coef = theta / sin_theta;
				res.x = q.x * coef;
				res.y = q.y * coef;
				res.z = q.z * coef;
			}
		}

		return res;
	}

    private static Quaternion quaExp ;
    private static float fAngle;
    private static float fSin;
	public static Quaternion GetQuatExp(Quaternion q)
	{
        quaExp = q;
		fAngle = Mathf.Sqrt(q.x * q.x + q.y * q.y + q.z * q.z);
		fSin = Mathf.Sin(fAngle);

        quaExp.w = Mathf.Cos(fAngle);

		if (Mathf.Abs(fSin) > 0.0001)
		{
			float coef = fSin / fAngle;
            quaExp.x = coef * q.x;
            quaExp.y = coef * q.y;
            quaExp.z = coef * q.z;
		}

		return quaExp;
	}

    /// <summary>
    /// SQUAD Spherical Quadrangle interpolation [Shoe87]
    /// </summary>
    private static Quaternion slerpP;
    private static Quaternion slerpQ;
    private static Quaternion rot;
    private static float slerpT;
	public static Quaternion GetQuatSquad(float t, Quaternion q0, Quaternion q1, Quaternion a0, Quaternion a1 )
	{
		slerpT = 2.0f * t * (1.0f - t);
		slerpP = Slerp(q0, q1, t);
		slerpQ = Slerp(a0, a1, t);
        rot = Slerp(slerpP, slerpQ, slerpT);
		return rot;
	}

    private static Quaternion q1Inv;
    private static Quaternion p0;
    private static Quaternion p2;
    private static Quaternion sum;
    public static Quaternion GetSquadIntermediate(Quaternion q0, Quaternion q1, Quaternion q2)
	{
		 q1Inv = GetQuatConjugate(q1);
		p0 = GetQuatLog(q1Inv * q0);
		p2 = GetQuatLog(q1Inv * q2);
		sum = new Quaternion(-0.25f * (p0.x + p2.x), -0.25f * (p0.y + p2.y), -0.25f * (p0.z + p2.z), -0.25f * (p0.w + p2.w));

		return q1 * GetQuatExp(sum);
	}

    /// <summary>
    /// Smooths the input parameter t.
    /// If less than k1 ir greater than k2, it uses a sin.
    /// Between k1 and k2 it uses linear interp.
    /// </summary>
    private static float ease_f;
    private static float ease_s;

	public static float Ease(float t, float k1, float k2)
	{
        ease_f = k1 * 2 / Mathf.PI + k2 - k1 + (1.0f - k2) * 2 / Mathf.PI;

		if (t < k1)
		{
            ease_s = k1 * (2 / Mathf.PI) * (Mathf.Sin((t / k1) * Mathf.PI / 2 - Mathf.PI / 2) + 1);
		}
		else
			if (t < k2)
			{
            ease_s = (2 * k1 / Mathf.PI + t - k1);
			}
			else
			{
            ease_s = 2 * k1 / Mathf.PI + k2 - k1 + ((1 - k2) * (2 / Mathf.PI)) * Mathf.Sin(((t - k2) / (1.0f - k2)) * Mathf.PI / 2);
			}

		return (ease_s / ease_f);
	}

    /// <summary>
    /// We need this because Quaternion.Slerp always uses the shortest arc.
    /// </summary>
    private static Quaternion retSlerp;
    private static float fCoeff0, fCoeff1, omega, invSin;
    public static Quaternion Slerp(Quaternion p, Quaternion q, float t)
	{
		float fCos = Quaternion.Dot(p, q);

		if ((1.0f + fCos) > 0.00001)
		{
			if ((1.0f - fCos) > 0.00001)
			{
				omega = Mathf.Acos(fCos);
				invSin = 1.0f / Mathf.Sin(omega);
				fCoeff0 = Mathf.Sin((1.0f - t) * omega) * invSin;
				fCoeff1 = Mathf.Sin(t * omega) * invSin;
			}
			else
			{
				fCoeff0 = 1.0f - t;
				fCoeff1 = t;
			}

            retSlerp.x = fCoeff0 * p.x + fCoeff1 * q.x;
            retSlerp.y = fCoeff0 * p.y + fCoeff1 * q.y;
            retSlerp.z = fCoeff0 * p.z + fCoeff1 * q.z;
            retSlerp.w = fCoeff0 * p.w + fCoeff1 * q.w;
		}
		else
		{
			fCoeff0 = Mathf.Sin((1.0f - t) * Mathf.PI * 0.5f);
			fCoeff1 = Mathf.Sin(t * Mathf.PI * 0.5f);

            retSlerp.x = fCoeff0 * p.x - fCoeff1 * p.y;
            retSlerp.y = fCoeff0 * p.y + fCoeff1 * p.x;
            retSlerp.z = fCoeff0 * p.z - fCoeff1 * p.w;
            retSlerp.w = p.z;
		}

		return retSlerp;
	}
}