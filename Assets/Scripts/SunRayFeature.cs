using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class SunRayFeature : ScriptableRendererFeature
{
    class SunRayPass : ScriptableRenderPass
    {
        public Material material;
        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            if (material == null) return;

            CommandBuffer cmd = CommandBufferPool.Get("Sun Ray Pass");
            //Blit(cmd, ref renderingData, material);
            var source = renderingData.cameraData.renderer.cameraColorTargetHandle;
            Blit(cmd, source, source, material);

            context.ExecuteCommandBuffer(cmd);
            CommandBufferPool.Release(cmd);
        }
    }

    SunRayPass pass;

    public Material material;

    public override void Create()
    {
        pass = new SunRayPass();
        //pass.renderPassEvent = RenderPassEvent.AfterRenderingPostProcessing;
        pass.renderPassEvent = RenderPassEvent.AfterRenderingTransparents;

        pass.material = material;
    }

    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        if (material != null)
            renderer.EnqueuePass(pass);
    }
}
