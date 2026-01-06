using UnityEngine;
using UnityEditor;
using UnityEngine.UIElements;

[CustomEditor(typeof(Planet))]
public class PlanetEditor:Editor
{
    Planet planet;
    public override void OnInspectorGUI()
    {
        base.OnInspectorGUI();
        DrawSettingsEditor(planet.shapeSettings,planet.OnShapeSettingChanged,ref planet.shapeSettingsFoldout);
        DrawSettingsEditor(planet.colorSettings,planet.OnColorSettingUpdated,ref planet.colorSettingsFoldout);
    }

    void DrawSettingsEditor(Object settings,System.Action onSettingUpdated,ref bool foldout)
    {
        foldout = EditorGUILayout.InspectorTitlebar(foldout, settings);
        using (var check = new EditorGUI.ChangeCheckScope())
        {
            if (!foldout)
                return;

            Editor editor = CreateEditor(settings);
            editor.OnInspectorGUI();

            if (check.changed)
            {
                if(onSettingUpdated != null)
                {
                    onSettingUpdated();
                }
            }
        }

    }
    private void OnEnable()
    {
        planet = (Planet)target;
    }
}
