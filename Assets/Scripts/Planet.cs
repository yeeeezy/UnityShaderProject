using UnityEngine;

// 星球类，负责生成和管理星球的网格和外观
public class Planet : MonoBehaviour
{
    [Range(2, 256)]
    public int gridResolution = 10; // 网格分辨率

    public ShapeSettings shapeSettings; // 形状设置
    public ColorSettings colorSettings; // 颜色设置

    public enum FaceRenderMask { All, Top, Bottom, Left, Right, Front, Back }
    public FaceRenderMask faceRenderMask; 

    [HideInInspector]
    public bool shapeSettingsFoldout; // 形状设置折叠状态
    [HideInInspector]
    public bool colorSettingsFoldout; // 颜色设置折叠状态

    [SerializeField, HideInInspector]
    private MeshFilter[] _meshFilterArray; // 网格过滤器数组
    private TerrainFace[] _faceArray;      // 地形面数组

    [SerializeField]
    ShapeGenerator _shapeGenerator; // 形状生成器
    ColorGenerator _colorGenerator; // 颜色生成器

    [SerializeField]
    private Material _surfaceMaterial;     // 表面材质

    [SerializeField]
    private PlanetShapeType _planetShape;      // 星球形状类型

    // 在Inspector中参数发生变化时自动调用，用于重新初始化和生成星球
    private void OnValidate()
    {
        GeneratePlanet();
    }

    // 初始化星球组件和地形面数组
    void Initialize()
    {
        if (shapeSettings == null)
        {
            Debug.LogWarning("Planet: ShapeSettings is not assigned. Initialization aborted.");
            return;
        }

        _shapeGenerator = new ShapeGenerator(shapeSettings);
        _colorGenerator = new ColorGenerator(colorSettings);

        // 如果网格过滤器数组未初始化，则分配空间
        if (_meshFilterArray == null || _meshFilterArray.Length == 0)
        {
            _meshFilterArray = new MeshFilter[6];
        }

        // 初始化六个方向的地形面数组
        _faceArray = new TerrainFace[6];

        // 立方体六个面的方向向量，分别对应上下左右前后
        Vector3[] faceDirections = { Vector3.up, Vector3.down, Vector3.left, Vector3.right, Vector3.forward, Vector3.back };

        // 遍历六个面，初始化网格对象和地形面
        for (int idx = 0; idx < 6; idx++)
        {
            // 如果当前面的网格对象未创建，则新建GameObject并配置组件
            if (_meshFilterArray[idx] == null)
            {
                GameObject meshObj = new GameObject($"Mesh_{idx}");
                meshObj.transform.parent = transform;
                meshObj.AddComponent<MeshRenderer>();
                _meshFilterArray[idx] = meshObj.AddComponent<MeshFilter>();
                _meshFilterArray[idx].sharedMesh = new Mesh();
            }
            _meshFilterArray[idx].GetComponent<MeshRenderer>().sharedMaterial = colorSettings.planetMaterial;
            // 创建地形面对象
            _faceArray[idx] = new TerrainFace(_shapeGenerator,_meshFilterArray[idx].sharedMesh, gridResolution, faceDirections[idx],this.transform.position);
        }
    }

    public void GeneratePlanet()
    {
        Initialize();
        GenerateMesh();
        GenerateColor();
    }

    // 当形状设置改变时调用，用于重新初始化和生成网格
    public void OnShapeSettingChanged()
    {
        Initialize();
        GenerateMesh();
    }

    // 当颜色设置改变时调用，仅重新生成颜色
    public void OnColorSettingUpdated()
    {
        Initialize();
        GenerateColor();
    }

    // 生成所有面的网格
    void GenerateMesh()
    {
        foreach (TerrainFace face in _faceArray)
        {
            face.ConstructMesh(_planetShape);
        }

        _colorGenerator.UpdateElevation(_shapeGenerator.elevationMinMax);
    }

    void GenerateColor()
    {
        foreach (MeshFilter meshFilter in _meshFilterArray)
        {
            if (meshFilter != null)
            {
                meshFilter.GetComponent<MeshRenderer>().sharedMaterial.color = colorSettings.planetColor;
            }
        }
    }
}
