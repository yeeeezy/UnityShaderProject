using System;
using UnityEngine;

[CreateAssetMenu(menuName = "Planet/Shape Settings")]
public class ShapeSettings : ScriptableObject
{
    public float planetRadius = 1f;
    public NoiseLayer[]  noiseLayers;

    [Serializable]
    public class NoiseLayer
    {
        public bool enabled = true;
        public bool useFirstLayerAsMask;
        public NoiseSettings noiseSettings;
    }  
}
