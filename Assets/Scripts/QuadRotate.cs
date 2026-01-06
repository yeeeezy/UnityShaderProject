using UnityEngine;

// This attribute makes the script run in the Editor even when not playing
[ExecuteAlways]
public class QuadRotate : MonoBehaviour
{
    void LateUpdate()
    {
        // In Play Mode, we use LateUpdate to follow the camera smoothly.
        if (Application.isPlaying)
        {
            UpdateRotation();
        }
    }

    // Logic extracted to a function so we can call it from different places
    void UpdateRotation()
    {
        Camera camToFace = null;

        // 1. If we are playing the game, use the Main Camera
        if (Application.isPlaying)
        {
            camToFace = Camera.main;
        }
        // 2. If we are in the Editor (Scene View), find the Scene Camera
        else
        {
#if UNITY_EDITOR
            // We use the internal UnityEditor class to find the Scene View camera
            if (UnityEditor.SceneView.lastActiveSceneView != null)
            {
                camToFace = UnityEditor.SceneView.lastActiveSceneView.camera;
            }
#endif
        }

        // Apply rotation if we found a camera
        if (camToFace != null)
        {
            // Simply copy the camera's rotation.
            transform.rotation = camToFace.transform.rotation;
        }
    }

#if UNITY_EDITOR
    // In the Editor, LateUpdate is lazy and doesn't run while you are dragging the camera.
    // OnRenderObject is called every single frame the Scene View renders, giving you real-time updates.
    void OnRenderObject()
    {
        if (!Application.isPlaying)
        {
            UpdateRotation();
        }
    }
#endif
}
