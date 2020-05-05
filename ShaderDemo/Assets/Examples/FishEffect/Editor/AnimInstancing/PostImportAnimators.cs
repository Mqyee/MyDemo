using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEditor;

namespace AnimationInstancing
{
    public class PostImportAnimators : AssetPostprocessor
    {

        static void OnPostprocessAllAssets(string[] importedAssets,
            string[] deletedAssets,
            string[] movedAssets,
            string[] movedFromAssetPaths)
        {
            foreach (string str in importedAssets)
            {
                if (str.Contains("Assets/Res_Best/Prefabs/") && str.EndsWith(".prefab"))
                {
                    GameObject go = AssetDatabase.LoadAssetAtPath<GameObject>(str);
                    var newPrefab = PrefabUtility.InstantiatePrefab(go) as GameObject;
                    if (newPrefab != null)
                    {
                        Animator[] animators = newPrefab.transform.GetComponentsInChildren<Animator>();
                        foreach (var ani in animators)
                        {
                            if (ani != null)
                            {
                                Debug.Log("animator 重新设置，path=" + str);
                                bool isChange = false;
                                if (ani.applyRootMotion == true)
                                {
                                    ani.applyRootMotion = false;
                                    isChange = true;
                                    Debug.Log("animator 重新设置applyRootMotion，applyRootMotion=" + ani.applyRootMotion);
                                }
                                //if (ani.cullingMode == AnimatorCullingMode.AlwaysAnimate)
                                //{
                                //    bool isAlways = ani.runtimeAnimatorController != null && ani.runtimeAnimatorController.name.EndsWith("_always");
                                //    if (!isAlways)
                                //    {
                                //        ani.cullingMode = AnimatorCullingMode.CullUpdateTransforms;
                                //        isChange = true;
                                //        Debug.Log("animator 重新设置cullingMode，cullingMode=" + ani.cullingMode);
                                //    }
                                //}
                                if (isChange == true)
                                {
                                    PrefabUtility.SaveAsPrefabAsset(newPrefab, str);
                                    isChange = false;
                                }
                            }
                        }
                        GameObject.DestroyImmediate(newPrefab);
                    }
                }
            }
        }

    }
}