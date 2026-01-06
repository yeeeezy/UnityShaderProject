using UnityEngine;

// �����࣬�������ɺ͹����������������
public class PlanetMagma : MonoBehaviour
{
    [Range(2, 256)]
    public int gridResolution = 10; // ����ֱ���

    public ShapeSettings shapeSettings; // ��״����
    public ColorSettings colorSettings; // ��ɫ����

    public enum FaceRenderMask { All, Top, Bottom, Left, Right, Front, Back }
    public FaceRenderMask faceRenderMask; 

    [HideInInspector]
    public bool shapeSettingsFoldout; // ��״�����۵�״̬
    [HideInInspector]
    public bool colorSettingsFoldout; // ��ɫ�����۵�״̬

    [SerializeField, HideInInspector]
    private MeshFilter[] _meshFilterArray; // �������������
    private TerrainFace[] _faceArray;      // ����������

    [SerializeField]
    ShapeGenerator _shapeGenerator; // ��״������
    ColorGenerator _colorGenerator; // ��ɫ������

    [SerializeField]
    private Material _surfaceMaterial;     // �������

    [SerializeField]
    private PlanetShapeType _planetShape;      // ������״����

    // ��Inspector�в��������仯ʱ�Զ����ã��������³�ʼ������������
    private void OnValidate()
    {
        GeneratePlanet();
    }

    // ��ʼ����������͵���������
    void Initialize()
    {
        if (shapeSettings == null)
        {
            Debug.LogWarning("Planet: ShapeSettings is not assigned. Initialization aborted.");
            return;
        }

        _shapeGenerator = new ShapeGenerator(shapeSettings);
        _colorGenerator = new ColorGenerator(colorSettings);

        // ����������������δ��ʼ���������ռ�
        if (_meshFilterArray == null || _meshFilterArray.Length == 0)
        {
            _meshFilterArray = new MeshFilter[6];
        }

        // ��ʼ����������ĵ���������
        _faceArray = new TerrainFace[6];

        // ������������ķ����������ֱ��Ӧ��������ǰ��
        Vector3[] faceDirections = { Vector3.up, Vector3.down, Vector3.left, Vector3.right, Vector3.forward, Vector3.back };

        // ���������棬��ʼ���������͵�����
        for (int idx = 0; idx < 6; idx++)
        {
            // �����ǰ����������δ���������½�GameObject���������
            if (_meshFilterArray[idx] == null)
            {
                GameObject meshObj = new GameObject($"Mesh_{idx}");
                meshObj.transform.parent = transform;
                meshObj.AddComponent<MeshRenderer>();
                _meshFilterArray[idx] = meshObj.AddComponent<MeshFilter>();
                _meshFilterArray[idx].sharedMesh = new Mesh();
            }
            _meshFilterArray[idx].GetComponent<MeshRenderer>().sharedMaterial = colorSettings.planetMaterial;
            // �������������
            _faceArray[idx] = new TerrainFace(_shapeGenerator,_meshFilterArray[idx].sharedMesh, gridResolution, faceDirections[idx],this.transform.position);
        }
    }

    public void GeneratePlanet()
    {
        Initialize();
        GenerateMesh();
        GenerateColor();
    }

    // ����״���øı�ʱ���ã��������³�ʼ������������
    public void OnShapeSettingChanged()
    {
        Initialize();
        GenerateMesh();
    }

    // ����ɫ���øı�ʱ���ã�������������ɫ
    public void OnColorSettingUpdated()
    {
        Initialize();
        GenerateColor();
    }

    // ���������������
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
