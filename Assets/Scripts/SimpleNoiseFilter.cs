using Unity.VisualScripting;
using UnityEngine;

public class SimpleNoiseFilter: INoiseFilter
{
    NoiseSettings _settings;
    Noise noise = new Noise();

    public SimpleNoiseFilter(NoiseSettings settings)
    {
        _settings = settings;
    }

    public float Evaluate(Vector3 point )
    {
        float noiseValue = 0;
        float frequency = _settings.baseRoughness;
        float amplitude = 1;
        for (int i = 0; i < _settings.numLayers; i++)
        {
            float v = noise.Evaluate(point * frequency + _settings.center);
            noiseValue += (v + 1) * 0.5f * amplitude;
            frequency *= _settings.roughness;
            amplitude *= _settings.persistence;
        } 
        noiseValue = Mathf.Max(0, noiseValue - _settings.minValue);
        return noiseValue*_settings.strength;
    }
}

public class Noise
{
    public float Evaluate(Vector3 point)
    {
        float xy = Mathf.PerlinNoise(point.x, point.y);
        float yz = Mathf.PerlinNoise(point.y + 100f, point.z + 100f);
        float zx = Mathf.PerlinNoise(point.z + 200f, point.x + 200f);
        return (xy + yz + zx) / 3f;
    }

}
