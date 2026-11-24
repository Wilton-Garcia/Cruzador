// rea decompile_all
// name: imp___stubs__realloc
// address: 0x100000d7a
// body: unavailable
// body_reason: Hopper's public Python API does not expose complete function body ranges
// provider: Hopper Disassembler launcher-sha256:3546631e054690585330f168ea1fe158486a5ca98b17dd400766efb0f920b956 (hopper)
// analysis_profile: 233f4c79700aa7230a0abf5deb8c6d6a495f3fc0308de2662f6efd1dea55c411
// limitations: REA loaded a verified thin Mach-O image prepared from the original source. Identity and file offsets refer to the original file. The owned temporary image and its Hopper document close together, including on MCP shutdown.; Results depend on Hopper's completed static analysis.
// pseudocode: provider-specific; not original source

    rax = (*_realloc_ptr)(ptr, size);
    return rax;
