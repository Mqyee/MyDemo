using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class PlantInterActive : MonoBehaviour
{
    private Animator animator;
    public float speed = 1;
    // Start is called before the first frame update
    void Start()
    {
        animator = gameObject.GetComponent<Animator>();
    }

    // Update is called once per frame
    void Update()
    {
        MoveByGetAxis();
        Vector4 playerpos = transform.position;
        Shader.SetGlobalVector("_ActorPos", playerpos);
    }

    void MoveByGetAxis()
    {
        float horizontal = Input.GetAxis("Horizontal");
        float vertical = Input.GetAxis("Vertical");
        transform.Translate(Vector3.right * horizontal * Time.deltaTime * speed);
        transform.Translate(Vector3.forward * vertical * Time.deltaTime * speed);
    }
}
