using UnityEngine;

public class StarFieldSpawner : MonoBehaviour
{
    public GameObject starPrefab;   // 拖入 StarPrefab
    public int starCount = 200;     // 星星数量
    public float radius = 200f;     // 星星“天空球”的半径

    void Start()
    {
        if (starPrefab == null)
        {
            Debug.LogError("StarFieldSpawner: starPrefab not set.");
            return;
        }

        for (int i = 0; i < starCount; i++)
        {
            // 在单位球上随机一个方向
            Vector3 dir = Random.onUnitSphere;
            Vector3 pos = dir * radius;

            // 生成星星
            GameObject star = Instantiate(starPrefab, pos, Quaternion.identity, transform);

            // 让星星朝向场景中心（或者摄像机），可选
            star.transform.LookAt(Vector3.zero);
        }
    }
}


