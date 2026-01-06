using UnityEngine;

[RequireComponent(typeof(Renderer))]
public class StarFlicker : MonoBehaviour
{
    public float baseIntensity = 3f;    
    public float flickerAmplitude = 1f; 
    public float flickerSpeed = 2f;     

    private Material _mat;
    private float _randomOffset;

    void Awake()
    {
        var renderer = GetComponent<Renderer>();
        
        _mat = renderer.material;

        
        _randomOffset = Random.Range(0f, 100f);
    }

    void Update()
    {
        if (_mat == null) return;

        float t = Time.time * flickerSpeed + _randomOffset;
        float flicker = 0.5f + 0.5f * Mathf.Sin(t);  

        float intensity = baseIntensity + flickerAmplitude * flicker;

        
        Color baseColor = Color.white; 
        Color emission = baseColor * intensity;

        _mat.SetColor("_EmissionColor", emission);
    }
}
