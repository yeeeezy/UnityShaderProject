using UnityEngine;

// 地形面类，用于生成球体或立方体的网格
public class TerrainFace
{
    private Mesh _mesh;                  // 网格对象
    private int _gridSize;               // 网格分辨率
    private Vector3 _faceNormal;         // 当前面法线
    private Vector3 _rightAxis;          // 局部右轴
    private Vector3 _upAxis;             // 局部上轴
    private Vector3 _origin;             // 形状原点
    private ShapeGenerator _shapeGenerator; // 形状生成器

    // 构造函数，初始化网格、分辨率、方向和原点
    public TerrainFace(ShapeGenerator shapeGenerator, Mesh mesh, int resolution, Vector3 localUp, Vector3 origin = default)
    {
        _shapeGenerator = shapeGenerator;
        _mesh = mesh;
        _gridSize = resolution;
        _faceNormal = localUp;
        _origin = origin == default ? Vector3.zero : origin;

        // 计算局部坐标轴
        _rightAxis = new Vector3(localUp.y, localUp.z, localUp.x);
        _upAxis = Vector3.Cross(localUp, _rightAxis);
    }

    // 构建网格，根据形状类型生成顶点和三角形
    public void ConstructMesh(PlanetShapeType shapeType)
    {
        int vertexCount = _gridSize * _gridSize;
        int triangleCount = (_gridSize - 1) * (_gridSize - 1) * 6;
        Vector3[] vertexArray = new Vector3[vertexCount]; // 顶点数组
        int[] triangleArray = new int[triangleCount];     // 三角形索引数组

        int trianglePointer = 0; // 三角形索引指针

        // 遍历网格点
        for (int row = 0; row < _gridSize; row++)
        {
            for (int col = 0; col < _gridSize; col++)
            {
                int vertexIndex = col + row * _gridSize; // 顶点索引
                Vector2 gridPercent = new Vector2(col, row) / (_gridSize - 1); // 网格百分比位置

                // 计算立方体和球体上的点，加入自定义原点
                Vector3 cubePoint = _origin + _faceNormal + (gridPercent.x - 0.5f) * 2 * _rightAxis + (gridPercent.y - 0.5f) * 2 * _upAxis;
                Vector3 spherePoint = (cubePoint - _origin).normalized + _origin; // 球体顶点也以原点为中心


                // 根据形状类型选择顶点
                Vector3 point = (shapeType == PlanetShapeType.Sphere) ? spherePoint : cubePoint;
                vertexArray[vertexIndex] = _shapeGenerator.CalculatePointOnPlanet(point,_origin,shapeType);

                // 生成三角形索引（排除最后一行和最后一列）
                if (col < _gridSize - 1 && row < _gridSize - 1)
                {
                    triangleArray[trianglePointer++] = vertexIndex;
                    triangleArray[trianglePointer++] = vertexIndex + _gridSize + 1;
                    triangleArray[trianglePointer++] = vertexIndex + _gridSize;
                    triangleArray[trianglePointer++] = vertexIndex;
                    triangleArray[trianglePointer++] = vertexIndex + 1;
                    triangleArray[trianglePointer++] = vertexIndex + _gridSize + 1;
                }
            }
        }
        // 清空网格并赋值
        _mesh.Clear();
        _mesh.vertices = vertexArray;
        _mesh.triangles = triangleArray;
        _mesh.RecalculateNormals(); // 重新计算法线
    }
}

// 行星形状枚举，定义支持的网格类型
public enum PlanetShapeType
{
    Sphere, // 球体
    Cube    // 立方体
}
