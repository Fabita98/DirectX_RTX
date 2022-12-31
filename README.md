# DirectX_RTX
## Project for RTGP course in Unimi
#### This is an extension of the original project made for the course of "Real Time Graphics Programming" of Università degli studi di Milano. ####
Since the .docx files in the original project gave for granted the familiarity with DirectX12, in the following document there will be shown some necessary information for the ones that, like me, have no knowledge about DirectX12 before starting to work on it and to give a better understanding of what is needed for a good comprehension of not only original version, but also for the changes applied in the "*dev*" branch of this work. This purpose will be realised through a brief explanation of the main DX12 structures with links to those specific topics directly on the DirectX documentation.

How to obtain **GPU sync** through **device creation** and entities like **swap-chain, command-queue, command-list, command-allocator, descriptor-heap** and **fence** will be shown in the following part:
- **Adapter**: trivially, the GPU which supports ray tracing. Here for more: https://www.3dgep.com/learning-directx-12-1/#query-directx-12-adapter;
- **Device**: a memory context that tracks allocations in GPU memory. Here for more: https://www.3dgep.com/learning-directx-12-1/#create-the-directx-12-device;
- **Swap-chain**: shows the rendered image to the screen storing at least two buffers (front & back). Back buffer is described through render target view(RTV). Here for more: https://www.3dgep.com/learning-directx-12-1/#create-the-swap-chain;
- **Command-queue**: as the name suggests, is the queue for the commands to be executed. Here for more:
https://www.3dgep.com/learning-directx-12-1/#command-queue;
- **Command-list**: used to issue copy, compute (dispatch), or draw commands. Here for more: https://www.3dgep.com/learning-directx-12-1/#command-list;
- **Command-allocator**: backing memory used by a command list which does not provide any functionality and can be accessed only by the command list. Here for more: https://www.3dgep.com/learning-directx-12-1/#create-a-command-allocator;
- **Descriptor-heap**: starting from DirectX12, **RTV** (**render target view**) are stored in this data structure, where a view references a resource in the GPU memory. Here for more: https://www.3dgep.com/learning-directx-12-1/#preamble; 
- **Fence**: for synchronizing commands sent to the command queue. Here for more: https://www.3dgep.com/learning-directx-12-1/#fence;

Now that the main topics of DirectX12 should be clear, we can proceed to the core of the applied changes, taking in account the final result and the operations needed to realize it without any problem, since all the work can be seen in the commits preceding the final one.

The scope of this project was to realise a scene where the instances on the background and on the foreground were to be colored accordingly to a certain *transparency* factor.
For this purpose, the addition of more instances was necessary, so the **Acceleration Structures** needed to be modified for what concerned the **Constant Buffers** used for each instance and the *NumDescs* parameter that needs to be changes depending on the triangle instances in the scene. Then, more triangle instances have been added in order to create a scene where three instances were placed on the foreground and the remaining three on the background. To do so, the **Shader Table** needed to be corrected through the following scheme: 

<img width="594" alt="image" src="https://user-images.githubusercontent.com/56884128/210101150-d27fb7ce-edf6-400d-ad07-7ba3fdb1049f.png">

So, the **Shader table** is now composed by:
- 1 **RayGen**;
- 2 **Miss Shaders**: 
  - 1 for primary ray;
  - 1 for shadow ray;
- 7 **Hit** instances:
  - 1 for the plane;
  - 6 for triangles;
  
  where only the instance n. 0 has both geometries in it.

While, the *transparency* condition was applied taking in account some parameters. So, in order to show what are we talking about, let's see the structure used for the purpose in the ```TraceRay()``` method:
```
void TraceRay(RaytracingAccelerationStructure AccelerationStructure,
              uint RayFlags,
              uint InstanceInclusionMask,
              uint RayContributionToHitGroupIndex,
              uint MultiplierForGeometryContributionToHitGroupIndex,
              uint MissShaderIndex,
              RayDesc Ray,
              inout payload_t Payload);
```
which, in our case, became:
```
TraceRay(gRtScene, 0, 0x80, 0, 2, 0, ray, NoTransPayload);
```
and, for the  instances on the foreground:
```
TraceRay(gRtScene, 0, 0x40, 0, 0, 0, ray, transparencyPayload);
```
where:
- ```gRtScene``` is the resource view to the **Top Level Acceleration Structure (TLAS)**;
- ```RayFlags``` is, in both cases, set to ```0``` because the choice was to act through the application of masks, using the following parameter;
- ```InstanceInclusionMask``` has different values based on the type of instance to take in account and accordingly to the ray type:
  - ```0xFF``` standing for **"RAY_FLAG_NONE"**;                            
  - ```0x80``` that stands for **"RAY_FLAG_CULL_NON_OPAQUE"**;
  - ```0x40``` that stands for **"RAY_FLAG_CULL_OPAQUE"**;
- ```RayContributionToHitGroupIndex``` is set on:
  - ```0``` for the primary rays;
  - ```1``` for the shadow ray;
  This parameter could be seen as the **ray index**.
  
  Indeed, for the **shadow ray** in the ```planeClosestHitShader```, the ```TraceRay()``` method is:
  ```    
  TraceRay(gRtScene, 0, 0xFF, 1, 0, 1, ray, shadowPayload);
  ```
- ```MultiplierForGeometryContributionToHitGroupIndex``` is set based on the geometries whose the specific ray takes in account, so:
  - ```2``` if the ray must consider both the plane and the triangles;
  - ```0``` if the ray must consider only the triangles;
- ```MissShaderIndex``` is set following the same criteria used for ```RayContributionToHitGroupIndex``` because the miss-shader entries are stored contiguously in the shader-table;
- ```RayPayload``` has different characteristics based on the type of the ray. Its structure is defined as follows:

``` 
struct RayPayload
{
    bool hasTransparency;
    float3 color;
}; 
```
So, payloads are defined in this way:

if  ```RayPayload.hasTransparency = true``` -> ```RayPayload = transparencyPayload```;

else -> ```RayPayload = NoTransPayload```;

On the other hand, ```shadowPayload``` is defined as follows:
```
struct ShadowPayload
{
    bool hit;
};
```


