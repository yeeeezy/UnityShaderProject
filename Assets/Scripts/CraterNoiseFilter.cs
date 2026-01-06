using UnityEngine;
using System.Collections.Generic;

public class CraterNoiseFilter : INoiseFilter
{
    NoiseSettings settings;
    Crater[] craters;

    struct Crater
    {
        public Vector3 center;
        public float radius;
    }

    public CraterNoiseFilter(NoiseSettings settings)
    {
        this.settings = settings;
        InitializeCraters();
    }

    void InitializeCraters()
    {
        craters = new Crater[settings.numCraters];
        
        // 1. 使用设置中的种子
        Random.InitState(settings.seed);

        int maxTries = 30;

        for (int i = 0; i < settings.numCraters; i++)
        {
            for (int k = 0; k < maxTries; k++)
            {
                Vector3 randomPoint = Random.onUnitSphere;

                // 2. 实现偏向分布 (Biased Distribution)
                // Random.value 返回 0.0 到 1.0
                float t = Random.value; 
                
                // 应用偏置：
                // 如果 bias = 1，t 保持不变（线性）。
                // 如果 bias = 2 (或更高)，t 会被拉向 0 (例如 0.5 * 0.5 = 0.25)。
                // 结果就是在 Lerp 插值时，数值更靠近 minRadius。
                float tBiased = Mathf.Pow(t, settings.distributionBias);
                
                // 使用 Lerp 在最小和最大半径之间插值
                float randomRadius = Mathf.Lerp(settings.minRadius, settings.maxRadius, tBiased);

                // 3. 检测重叠
                if (!IsOverlapping(randomPoint, randomRadius, i))
                {
                    craters[i] = new Crater { center = randomPoint, radius = randomRadius };
                    break;
                }

                if (k == maxTries - 1)
                {
                    craters[i] = new Crater { center = Vector3.zero, radius = 0 };
                }
            }
        }
    }

    bool IsOverlapping(Vector3 center, float radius, int currentIndex)
    {
        for (int j = 0; j < currentIndex; j++)
        {
            Crater existing = craters[j];
            if (existing.radius <= 0) continue;

            float dist = Vector3.Distance(center, existing.center);
            
            // 保持 1.1倍 距离防止切边
            if (dist < (radius + existing.radius) * 1.1f)
            {
                return true;
            }
        }
        return false;
    }

    public float Evaluate(Vector3 point)
    {
        float craterHeight = 0;

        for (int i = 0; i < settings.numCraters; i++)
        {
            if (craters[i].radius <= 0) continue;

            float x = Vector3.Distance(point, craters[i].center) / craters[i].radius;

            if (x > 1.0f + settings.rimWidth) continue;

            float cavity = x * x - 1;
            float rimX = Mathf.Min(x - 1 - settings.rimWidth, 0);
            float rim = settings.rimSteepness * rimX * rimX;

            float craterShape = SmoothMax(cavity, settings.floorHeight, settings.smoothness);
            craterShape = SmoothMin(craterShape, rim, settings.smoothness);

            craterHeight += craterShape * craters[i].radius;
        }

        return craterHeight * settings.strength;
    }

    float SmoothMin(float a, float b, float k)
    {
        float h = Mathf.Clamp01(0.5f + 0.5f * (b - a) / k);
        return Mathf.Lerp(b, a, h) - k * h * (1.0f - h);
    }

    float SmoothMax(float a, float b, float k)
    {
        return -SmoothMin(-a, -b, k);
    }
}