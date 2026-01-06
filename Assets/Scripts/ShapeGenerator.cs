using UnityEngine;

public class ShapeGenerator 
{
    ShapeSettings settings;
    INoiseFilter[] noiseFilters;
    public MinMax elevationMinMax;
    public ShapeGenerator(ShapeSettings settings)
    {
        this.settings = settings;

        // Defensive null checks: when editing in the Inspector OnValidate may run
        // before assets (like ShapeSettings) are assigned. Handle nulls gracefully.
        if (settings == null || settings.noiseLayers == null)
        {
            noiseFilters = new INoiseFilter[0];
            return;
        }

        noiseFilters = new INoiseFilter[settings.noiseLayers.Length];
        for (int i = 0; i < noiseFilters.Length; i++)
        {
            var layer = settings.noiseLayers[i];
            var noiseSettings = layer != null ? layer.noiseSettings : null;
            noiseFilters[i] = FilterFactory.CreateNoiseFilter(noiseSettings);
        }
        elevationMinMax = new MinMax();
    }
 
    public Vector3 CalculatePointOnPlanet(Vector3 points, Vector3 origin,PlanetShapeType shapeType)
    {
        if(shapeType == PlanetShapeType.Sphere) 
        {
            points -= origin;
            float elevation = 0;
            float firstLayerValue = 0;

            if (noiseFilters.Length > 0 && noiseFilters[0] != null)
            {
                firstLayerValue = noiseFilters[0].Evaluate(points);
                if (settings.noiseLayers.Length > 0 && settings.noiseLayers[0] != null && settings.noiseLayers[0].enabled)
                {
                    elevation = firstLayerValue;
                }
            }

            for (int i = 1; i < noiseFilters.Length; i++)
            {
                if (settings.noiseLayers.Length > i && settings.noiseLayers[i] != null && settings.noiseLayers[i].enabled && noiseFilters[i] != null)
                {
                    float mask = settings.noiseLayers[i].useFirstLayerAsMask ? firstLayerValue : 1;
                    elevation += noiseFilters[i].Evaluate(points) * mask;
                }
            }
            elevation = settings.planetRadius * (1 + elevation);
            elevationMinMax.AddValue(elevation);
            return origin + points.normalized * elevation;
        }
        return points;
    }

}
