using UnityEngine;

public static class FilterFactory 
{
    public static INoiseFilter CreateNoiseFilter(NoiseSettings settings)
    {
        switch (settings.filterType)
        {
            case NoiseSettings.FilterType.Simple:
                return new SimpleNoiseFilter(settings);
            case NoiseSettings.FilterType.Rigid:
                return new RigidNoiseFilter(settings);
            case NoiseSettings.FilterType.Crater:
                return new CraterNoiseFilter(settings);
            default:
                return null;
        }
    }
}
