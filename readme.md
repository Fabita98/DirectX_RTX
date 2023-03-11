# DirectX_RTX: blend tuning by traversing instances   
## Project for the RTGP course at Unimi
#### This is an extension of the original project in the "*master*" branch and has been realised for the "Real Time Graphics Programming" course at the Università degli studi di Milano. ####
Since the .docx files in the original project assumed the familiarity with DirectX12, the following document will also provide some necessary information for those who, like me, had no knowledge of DirectX12 before starting to work on it and to give a better understanding of the applied changes in the "*dev*" branch of this project. This purpose will be achieved through a brief explanation of the main DX12 structures with links leading directly to the specific topic covered in the DirectX documentation. This will be followed by a presentation of what has been added and changed in this work.

How to obtain **GPU synchronisation** through **device creation** and entities like **swap-chain, command-queue, command-list, command-allocator, descriptor-heap** and **fence** will be shown in the following part:
- **Adapter**: trivially, the GPU that supports ray tracing. 
  Here for more: https://www.3dgep.com/learning-directx-12-1/#query-directx-12-adapter;
- **Device**: a memory context that tracks allocations in GPU memory. 
  Here for more: https://www.3dgep.com/learning-directx-12-1/#create-the-directx-12-device;
- **Swap-chain**: shows the rendered image on the screen storing at least two buffers (front & back). The back buffer is described by the render target view (RTV). 
  Here for more: https://www.3dgep.com/learning-directx-12-1/#create-the-swap-chain;
- **Command-queue**: as the name suggests, this is the queue of the commands to be executed. 
  Here for more: https://www.3dgep.com/learning-directx-12-1/#command-queue;
- **Command-list**: used to issue copy, compute (dispatch), or draw commands.
  Here for more: https://www.3dgep.com/learning-directx-12-1/#command-list;
- **Command-allocator**: backing memory used by a command list which provides no functionality and can only be accessed by the command list.
  Here for more: https://www.3dgep.com/learning-directx-12-1/#create-a-command-allocator;
- **Descriptor-heap**: render target view (RTV) is stored in this data structure, where a view references a resource in the GPU memory.
  Here for more: https://www.3dgep.com/learning-directx-12-1/#preamble; 
- **Fence**: for synchronising commands that are sent to the command queue.
  Here for more: https://www.3dgep.com/learning-directx-12-1/#fence;

It is worth noting that the **any-hit shader**, which only runs with non-opaque intersections, is not even launched because of the ```D3D12_RAYTRACING_GEOMETRY_FLAG_OPAQUE``` flag used in the acceleration structure which sets both geometries to be opaque.

Now that the main topics used in this DirectX project have been presented, we can move on to the core of the applied changes, considering the final result for the analysis of the changes and additions required to achieve it, as all the work can be seen in the previous commits.

The scope of this project was to realise a scene where the background and foreground instances would be coloured according to some sort of *transparency* factor. To achieve this, more instances had to be added, so the **Acceleration Structures** had to be modified in terms of the **Constant Buffers** used for each instance and the ```NumDescs``` parameter which had to be changed depending on the number of triangle instances in the scene. Then, more triangle instances were added in order to create a scene with three instances placed in the foreground and the remaining three placed in the background. To do this, also the **Shader Table** had to be corrected using the following scheme: 

<img width="594" alt="image" src="https://user-images.githubusercontent.com/56884128/210101150-d27fb7ce-edf6-400d-ad07-7ba3fdb1049f.png">

So, the **Shader table** is now composed by:
- 1 **RayGen**;
- 2 **Miss Shaders**: 
  - 1 for primary ray;
  - 1 for shadow ray;
- 7 **Hit** instances:
  - 1 for the plane;
  - 6 for triangles;
  
where the instance n. 0 is the only one containing both geometries.

However, the *transparency* condition was realised taking into account some properties like:
- the possibility to use the flags belonging to either geometry definitions and/or of the single instances, tuning the behaviour on a more/less general/individual layer;
- the use of two different rays crossing distinct instances depending on the properties of these latter:
  - the first ray traverses the only instances with the transparency factor where the former is defined with its own payload;
  - a second ray crosses the remaining instances, without the transparency factor, where the former has been defined with its own payload as well;

To give a better idea of what we are talking about, in the following is shown the structure used for this purpose, written in the ```TraceRay()``` method into the Shaders.hlsl file:
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
which, for the instances in the background, became:
```
TraceRay(gRtScene, 0, 0x80, 0, 2, 0, ray, NoTransPayload);
```
and, for the foreground instances:
```
TraceRay(gRtScene, 0, 0x40, 0, 0, 0, ray, transparencyPayload);
```
where:
- ```gRtScene``` is the resource view pointing to the **Top Level Acceleration Structure (TLAS)**;
- ```RayFlags``` is set to ```0``` in both cases because the decision of filtering the ray-instance traversal was taken by acting through the application of masks, exploiting the characteristics described in the following;
- ```InstanceInclusionMask``` has different values depending on the instance and ray types:
  - ```0xFF``` standing for **"RAY_FLAG_NONE"**, that does not apply any specific conditions to the scene traversal;                            
  - ```0x80``` standing for **"RAY_FLAG_CULL_NON_OPAQUE"** which causes the ray to ignore the instances marked with the "NON_OPAQUE" flag, i.e. ignoring all the instances which are to consider having the *transparency* factor;
  - ```0x40``` standing for **"RAY_FLAG_CULL_OPAQUE"** that, on the contrary, causes the ray to ignore the only instances marked with the "OPAQUE" flag, i.e. ignoring the instances that do not have the *transparency* factor;
- ```RayContributionToHitGroupIndex```, which could be seen as the **ray index**, is set to:
  - ```0``` for the primary rays;
  - ```1``` for the shadow ray;

  Indeed, for the **shadow ray tracing method** defined in the ```planeClosestHitShader```, the ```TraceRay()``` method is defined as follows:
  ```    
  TraceRay(gRtScene, 0, 0xFF, 1, 0, 1, ray, shadowPayload);
  ```
- ```MultiplierForGeometryContributionToHitGroupIndex``` is set to different values depending on the geometries considered by the specific ray, i.e:
  - ```2``` if the ray has to consider both the plane and the triangle geometries;
  - ```0``` if the ray only has to consider the triangles;
- ```MissShaderIndex``` is set adopting the same criteria used for ```RayContributionToHitGroupIndex``` because the miss-shader entries are stored contiguously in the shader-table;
- ```RayPayload``` has different properties depending on the ray type and this is the **key attribute** used to achieve the goal of this project. Its structure is defined as follows:

  ``` 
  struct RayPayload
  {
    bool hasTransparency;
    float3 color;
  }; 
  ```
  Hence, the ```bool``` attribute is the only one to be modified in the ```rayGen()``` method according to the ray type as shown below:
  ```
  RayPayload NoTransPayload;
  NoTransPayload.hasTransparency = false;
  ``` 
  while, for the instances to consider having the transaparency factor:
  ```
  RayPayload transparencyPayload;
  transparencyPayload.hasTransparency = true;
  ```
    On the other hand, ```shadowPayload``` is defined as follows:
    ```
    struct ShadowPayload
    {
        bool hit;
    };
    ```
Subsequently, considering what described until now, the **blending** was tuned consequently through the following code in the shader file, more specifically in the ```triangleClosestHitShader```:
```
void triangleChs(inout RayPayload payload, in BuiltInTriangleIntersectionAttributes attribs)
{
    float3 barycentrics = float3(1.0 - attribs.barycentrics.x - attribs.barycentrics.y, attribs.barycentrics.x, attribs.barycentrics.y);
    if(payload.hasTransparency) 
    {
        payload.color = A * (barycentrics.x + 0.65f) + B * (barycentrics.y + 0.65f) + C * (barycentrics.z + 0.65f);
    }
    else 
    {
        payload.color = A * barycentrics.x + B * barycentrics.y + C * barycentrics.z;
    }
}
```
where the colour for the triangle instances has been tuned considering the ```RayPayload``` which was previously described, i.e:
- if the ray crosses the "NOT_OPAQUE" instances -> the considered payload is the ```transparencyPayload``` -> only the *transparent* instances are coloured according to the blending defined in the first condition body;
- if the ray traverses the "OPAQUE" instances -> the considered payload becomes the ```NoTransPayload``` -> only the *not transparent* instances are colored following the blending defined in the "else" condition body; 

It is therefore useful to note that in the geometry definition, both geometries (triangles and plane) were defined with ```D3D12_RAYTRACING_GEOMETRY_FLAG_OPAQUE``` since this property can always be overridden in the per-instance description. Indeed, when the ```instanceDescs``` were defined in the "for" cycles, the same attribute was modified according to the desired behaviour in the scene through the mask attribute, taking into account the instance positions either in the foreground or in the background.

Another required change in order to add triangle instances in the scene was to adjust the correct memory locations in the shader table, recalculating the **Shader Table entry size** and to map each buffer in this table.
This task was accomplished by considering the ProgramID and constant-buffer data as shown below:
```
uint8_t* pEntryx = pData + mShaderTableEntrySize * x;
memcpy(pEntryx, pRtsoProps->GetShaderIdentifier(kTriHitGroup), D3D12_SHADER_IDENTIFIER_SIZE_IN_BYTES);
assert(((uint64_t)(pEntryx + D3D12_SHADER_IDENTIFIER_SIZE_IN_BYTES) % 8) == 0);
*(D3D12_GPU_VIRTUAL_ADDRESS*)(pEntryx + D3D12_SHADER_IDENTIFIER_SIZE_IN_BYTES) = mpConstantBuffer[y]->GetGPUVirtualAddress();
```
where "x" is the number that gives the correct position in the shader table for each object, starting from the primary ray, through the shadow one and ending to the triangle and plane instances. Note that ```mpConstantBuffer[y]``` only refers to triangle instances so "y" goes from 0 to 5 (cause the triangle instances are 6).

Then, the per-instance properties were then modified using two different "for" cycles:
  - the first one considers and defines the instances from 1 to 3, which are the "transparent" ones in the foreground:

    ```
      for (uint32_t i = 1; i < 4; i++)
        {
            instanceDescs[i].InstanceID = i;
            instanceDescs[i].InstanceContributionToHitGroupIndex = (i * 2) + 2;
            mat4 m = transpose(transformation[i]);
            memcpy(instanceDescs[i].Transform, &m, sizeof(instanceDescs[i].Transform));
            instanceDescs[i].AccelerationStructure = pBottomLevelAS[1]->GetGPUVirtualAddress();
            instanceDescs[i].InstanceMask = 0x40 ;                                    
            instanceDescs[i].Flags = D3D12_RAYTRACING_INSTANCE_FLAG_FORCE_NON_OPAQUE;
        }
    ```
  - the second one goes from 4 to 6 and defines the "non-transparent" instances in the background:

    ```
    for (uint32_t i = 4; i < 6; i++) 
      {
          instanceDescs[i].InstanceID = i;
          instanceDescs[i].InstanceContributionToHitGroupIndex = (i * 2) + 2;  
          mat4 m = transpose(transformation[i]);
          memcpy(instanceDescs[i].Transform, &m, sizeof(instanceDescs[i].Transform));
          instanceDescs[i].AccelerationStructure = pBottomLevelAS[1]->GetGPUVirtualAddress();        
          instanceDescs[i].InstanceMask = 0x80;                                                          
          instanceDescs[i].Flags = D3D12_RAYTRACING_INSTANCE_FLAG_FORCE_OPAQUE;
      }
    ```
  
The instance n. 0, containing both geometries and still one instance for each of them, is still defined in its separate piece of code, as shown below:
```
instanceDescs[0].InstanceID = 0;
instanceDescs[0].InstanceContributionToHitGroupIndex = 0;
memcpy(instanceDescs[0].Transform, &transformation[0], sizeof(instanceDescs[0].Transform));
instanceDescs[0].AccelerationStructure = pBottomLevelAS[0]->GetGPUVirtualAddress();
instanceDescs[0].InstanceMask = 0x80;
instanceDescs[0].Flags = D3D12_RAYTRACING_INSTANCE_FLAG_FORCE_OPAQUE;
```
but it is now marked with the ```0x80``` mask flag because it belongs to the opaque instance group.

Finally, in the "Video" folder you will find a video demonstration that shows the final result of what has been described so far.
On the other hand, below there are some useful references that helped me to get the correct information required to realise this project:
- Learning DirectX 12 – Lesson 1 – Initialize DirectX 12 | 3D Game Engine Programming (https://www.3dgep.com/learning-directx-12-1);
- Learning DirectX 12 – Lesson 2 – Rendering | 3D Game Engine Programming (https://www.3dgep.com/learning-directx-12-2);
- Learning DirectX 12 – Lesson 3 – Framework | 3D Game Engine Programming (https://www.3dgep.com/learning-directx-12-3);
- DX12 Raytracing tutorial - Part 1 | NVIDIA Developer (https://developer.nvidia.com/rtx/raytracing/dxr/dx12-raytracing-tutorial-part-1);
- DX12 Raytracing tutorial - Part 2 | NVIDIA Developer (https://developer.nvidia.com/rtx/raytracing/dxr/dx12-raytracing-tutorial-part-2);
- Scratchapixel (https://www.scratchapixel.com/) mainly for the following topics:
Accelerating 3D rendering, Mathematics for Computer Graphics and 3D Rendering for Beginners;
