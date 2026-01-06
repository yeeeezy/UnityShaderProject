using UnityEngine;

[System.Serializable]
public class NoiseSettings
{
    public enum FilterType { Simple, Rigid ,Crater};
    public FilterType filterType;

    public float strength = 1;
    [Range(0.1f, 10f)]
    public float weightMultiplier = 3f; // >1 increases contrast (pushes values toward 0 or 1)
    [Range(1,8)]
    public int numLayers = 1;
    public float persistence = 0.5f;
    public float baseRoughness = 1;
    public float roughness = 2;
    public Vector3 center;
    public float minValue=0.5f;
    
    // Crater
    public bool enabled = true;
    [Header("Crater Gen")]
    public int numCraters = 30;     // 陨石坑数量
    public float minRadius = 0.05f; // 最小半径
    public float maxRadius = 0.2f;  // 最大半径
    
    [Header("Shape Params")]
    public float floorHeight = -0.8f; // 坑底高度 (对应 HLSL 中的 floorHeight)
    public float rimWidth = 0.6f;     // 边缘宽度 (对应 HLSL 中的 rimWidth)
    public float rimSteepness = 0.3f; // 边缘陡峭度 (对应 HLSL 中的 rimSteepness)
    public float smoothness = 0.3f;   // 平滑混合度 (对应 HLSL 中的 smoothness)
    [Header("Generator Settings")]
    public int seed = 42; // 随机种子

    [Tooltip("分布偏好：1=均匀分布，数值越大，生成小坑的概率越高")]
    [Range(1f, 5f)]
    public float distributionBias = 2.0f; // 默认2，偏向小坑
}
