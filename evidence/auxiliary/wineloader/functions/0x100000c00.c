// rea decompile_all
// name: sub_100000c00
// address: 0x100000c00
// body: unavailable
// body_reason: Hopper's public Python API does not expose complete function body ranges
// provider: Hopper Disassembler launcher-sha256:3546631e054690585330f168ea1fe158486a5ca98b17dd400766efb0f920b956 (hopper)
// analysis_profile: 233f4c79700aa7230a0abf5deb8c6d6a495f3fc0308de2662f6efd1dea55c411
// limitations: REA loaded a verified thin Mach-O image prepared from the original source. Identity and file offsets refer to the original file. The owned temporary image and its Hopper document close together, including on MCP shutdown.; Results depend on Hopper's completed static analysis.
// pseudocode: provider-specific; not original source

    rbx = arg0;
    if (rax != 0x0) {
            intrinsic_movaps(var_C0, xmm0);
            intrinsic_movaps(var_B0, xmm1);
            intrinsic_movaps(var_A0, xmm2);
            intrinsic_movaps(var_90, xmm3);
            intrinsic_movaps(var_80, xmm4);
            intrinsic_movaps(var_70, xmm5);
            intrinsic_movaps(var_60, xmm6);
            intrinsic_movaps(var_50, xmm7);
    }
    r14 = 0x64;
    rax = malloc(0x64);
    if (rax == 0x0) {
            rax = fwrite("Virtual memory exhausted.\n", 0x1a, 0x1, **___stderrp);
            exit(0x1);
    }
    r15 = rax;
    r12 = &var_40;
    while (true) {
            rax = vsnprintf(r15, r14, rbx, r12);
            if (rax == 0xffffffff) {
                    r14 = r14 + r14;
                    free(r15);
                    rax = malloc(r14 + 0x0 + CARRY(RFLAGS(cf)));
                    r15 = rax;
                    if (rax != 0x0) {
                            continue;
                    }
                    temp_0 = 0x1;
                    break;
            }
            if (r14 > sign_extend_64(rax)) {
                    rax = r15;
                    temp_0 = 0x0;
                    break;
            }
            r14 = sign_extend_64(rax + 0x1);
            free(r15);
            rax = malloc(r14 + 0x0 + CARRY(RFLAGS(cf)));
            r15 = rax;
            if (rax != 0x0) {
                    continue;
            }
            temp_0 = 0x1;
            break;
    }
    if (temp_0 != 0x0) {
            rax = fwrite("Virtual memory exhausted.\n", 0x1a, 0x1, **___stderrp);
            exit(0x1);
    }
    return rax;
