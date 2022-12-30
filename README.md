# DirectX_RTX
### Project for RTGP course in Unimi
This is an extension of the original project made for the course of "Real Time Graphics Programming" of Università degli studi di Milano. 
Since the .docx files in the original project gave for granted the familiarity with DirectX12, in the following document there will be shown some necessary information for the ones that, like me, have no knowledge about DirectX12 before starting to work on it and to give a better understanding of what is needed for a good comprehension of not only original version, but also for the changes applied in the "*dev*" branch. This purpose will be realised through a brief explanation of the main DX12 structures and the direct links to those specific topics on the DirectX documentation.
**GPU sync** through: **device creation** and entities like **swap-chain, command-queue, command-list, command-allocator, descriptor-heap** and **fence** will be shown in the following part.
- **Adapter**: trivially, the GPU which supports ray tracing. Here for more: https://www.3dgep.com/learning-directx-12-1/#query-directx-12-adapter;
- **Device**: a memory context that tracks allocations in GPU memory. Here for more: https://www.3dgep.com/learning-directx-12-1/#create-the-directx-12-device;
- **Swap-chain**: shows the rendered image to the screen storing at least two buffers (front & back). Back buffer is described through render target view(RTV). Here for more: https://www.3dgep.com/learning-directx-12-1/#create-the-swap-chain;
- **Command-queue**: as the name suggests, is the queue for the commands to be executed. Here for more:
https://www.3dgep.com/learning-directx-12-1/#command-queue;
- **Command-list**: used to issue copy, compute (dispatch), or draw commands. Here for more: https://www.3dgep.com/learning-directx-12-1/#command-list;
- **Command-allocator**: backing memory used by a command list which does not provide any functionality and can be accessed only by the command list. Here for more: https://www.3dgep.com/learning-directx-12-1/#create-a-command-allocator;
- **Descriptor-heap**: starting from DirectX12, **RTV** (**render target view**) are stored in this data structure, where a view references a resource in the GPU memory. Here for more: https://www.3dgep.com/learning-directx-12-1/#preamble; 
- **Fence**: for synchronizing commands sent to the command queue. Here for more: https://www.3dgep.com/learning-directx-12-1/#fence;

Now that the main parts of DirectX12 should be clear, we can proceed to the core of the changes applied, taking in account only the final result and the operations needed to make it exist without any problem, since all the work can be seen in the commits preceding the final one.
For the purpose of the work, the addition of more instances was necessary, so the Acceleration Structures needed to be modified for what concerned the **ConstantBuffers** used for each instance and the *NumDescs* parameter. Then, more triangle instances have been added in order to create a scene where three instances were placed on the foreground and the remaining three on the background. To do so, the **ShaderTable** needed to be corrected through the following scheme: 

<img width="594" alt="image" src="https://user-images.githubusercontent.com/56884128/210101150-d27fb7ce-edf6-400d-ad07-7ba3fdb1049f.png">

