using Unity.Mathematics;
using UnityEngine;

public class RigidNoiseFilter : INoiseFilter
{
    NoiseSettings _settings;
    Noise noise = new Noise();

    public RigidNoiseFilter(NoiseSettings settings)
    {
        _settings = settings;
    }

    public float Evaluate(Vector3 point )
    {
        float noiseValue = 0;
        float frequency = _settings.baseRoughness;
        float amplitude = 1;
        float weight = 1;

        for (int i = 0; i < _settings.numLayers; i++)
        {
            float v  = 1-Mathf.Abs((noise.Evaluate(point * frequency + _settings.center)-0.5f)*2);
            v=Mathf.Pow(v,_settings.weightMultiplier);
            v*=weight; 
            weight = v;
            noiseValue += v* amplitude;
            frequency *= _settings.roughness;
            amplitude *= _settings.persistence;
        } 
        // apply minValue cutoff, then clamp and apply contrast to push extremes
        noiseValue = Mathf.Max(0, noiseValue - _settings.minValue);
        // noiseValue = Mathf.Clamp01(noiseValue);
        // if (_settings.contrast != 1f)
        // {
        //     noiseValue = Mathf.Pow(noiseValue, _settings.contrast);
        // }
        return noiseValue * _settings.strength;
    }

}
