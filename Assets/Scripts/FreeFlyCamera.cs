using UnityEngine;
// 引入新输入系统的命名空间
using UnityEngine.InputSystem;

public class FreeFlyCamera : MonoBehaviour
{
    [Header("Settings")]
    [Tooltip("鼠标灵敏度")]
    public float mouseSensitivity = 0.5f; // 新系统灵敏度计算方式不同，默认值调低一些

    [Tooltip("正常移动速度")]
    public float moveSpeed = 10.0f;

    [Tooltip("按住Shift时的加速倍率")]
    public float boostMultiplier = 3.0f;

    [Tooltip("滚轮缩放速度")]
    public float scrollSpeed = 5.0f; // 新系统滚轮数值很大，这里数值调小

    private float rotationX = 0.0f;
    private float rotationY = 0.0f;

    void Start()
    {
        Vector3 rot = transform.localEulerAngles;
        rotationX = rot.x;
        rotationY = rot.y;
    }

    void Update()
    {
        // 检查鼠标和键盘是否存在（防止空引用）
        if (Mouse.current == null || Keyboard.current == null) return;

        // 1. 只有按住鼠标右键时
        if (Mouse.current.rightButton.isPressed)
        {
            Cursor.lockState = CursorLockMode.Locked;
            Cursor.visible = false;

            // --- 视角旋转 (Look) ---
            // 新系统直接读取鼠标Delta值
            Vector2 mouseDelta = Mouse.current.delta.ReadValue();
            
            float mouseX = mouseDelta.x * mouseSensitivity * 0.1f; // 0.1f是修正系数
            float mouseY = mouseDelta.y * mouseSensitivity * 0.1f;

            rotationY += mouseX;
            rotationX -= mouseY;

            rotationX = Mathf.Clamp(rotationX, -90f, 90f);

            transform.localRotation = Quaternion.Euler(rotationX, rotationY, 0);

            // --- 键盘移动 (Move) ---
            float currentSpeed = moveSpeed;

            if (Keyboard.current.shiftKey.isPressed)
            {
                currentSpeed *= boostMultiplier;
            }

            Vector3 moveDirection = Vector3.zero;

            // 读取键盘按键
            if (Keyboard.current.wKey.isPressed) moveDirection += transform.forward;
            if (Keyboard.current.sKey.isPressed) moveDirection -= transform.forward;
            if (Keyboard.current.aKey.isPressed) moveDirection -= transform.right;
            if (Keyboard.current.dKey.isPressed) moveDirection += transform.right;

            // Q/E 升降
            if (Keyboard.current.eKey.isPressed) moveDirection += Vector3.up;
            if (Keyboard.current.qKey.isPressed) moveDirection += Vector3.down;

            transform.position += moveDirection * currentSpeed * Time.deltaTime;
        }
        else
        {
            Cursor.lockState = CursorLockMode.None;
            Cursor.visible = true;
        }

        // --- 鼠标滚轮 ---
        // 新系统滚轮返回的值通常是 120 的倍数，需要做规范化处理
        float scrollValue = Mouse.current.scroll.y.ReadValue();
        if (Mathf.Abs(scrollValue) > 0.1f)
        {
            // 归一化滚轮方向 (-1 或 1)
            float direction = Mathf.Sign(scrollValue);
            
            float scrollMoveSpeed = scrollSpeed;
            if (Keyboard.current.shiftKey.isPressed) scrollMoveSpeed *= boostMultiplier;
            
            transform.position += transform.forward * direction * scrollMoveSpeed * Time.deltaTime * 50f; // *50补足速度差
        }
    }
}