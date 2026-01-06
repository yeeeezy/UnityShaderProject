using UnityEngine;

public class ColorGenerator
{
    ColorSettings settings;
    public ColorGenerator(ColorSettings settings)
    {
        this.settings = settings;
    }
    public void UpdateElevation(MinMax elevationMinMax)
    {
        settings.planetMaterial.SetVector("_ElevationMinMax", new Vector4(elevationMinMax.Min, elevationMinMax.Max,0,0));
        Debug.Log($"Elevation Min: {elevationMinMax.Min}, Max: {elevationMinMax.Max}");
    }
}
