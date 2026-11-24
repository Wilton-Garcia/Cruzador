// rea decompile_all
// name: EntryPoint
// address: 0x100000670
// body: unavailable
// body_reason: Hopper's public Python API does not expose complete function body ranges
// provider: Hopper Disassembler launcher-sha256:3546631e054690585330f168ea1fe158486a5ca98b17dd400766efb0f920b956 (hopper)
// analysis_profile: 233f4c79700aa7230a0abf5deb8c6d6a495f3fc0308de2662f6efd1dea55c411
// limitations: REA loaded a verified thin Mach-O image prepared from the original source. Identity and file offsets refer to the original file. The owned temporary image and its Hopper document close together, including on MCP shutdown.; Results depend on Hopper's completed static analysis.
// pseudocode: provider-specific; not original source

    r12 = arg1;
    r13 = arg0;
    r14 = *arg1;
    var_44 = 0x400;
    rax = malloc(0x400);
    if (rax == 0x0) {
            rax = fwrite("Virtual memory exhausted.\n", 0x1a, 0x1, **___stderrp);
            exit(0x1);
    }
    r15 = rax;
    rax = _NSGetExecutablePath(rax, &var_44);
    if (rax != 0x0) goto loc_1000006ea;
    goto loc_1000006ce;

loc_1000006ea:
    free(r15);
    goto loc_1000006f2;

loc_1000006ce:
    rbx = realpath$DARWIN_EXTSN(r15, 0x0);
    free(r15);
    if (rbx == 0x0) goto loc_1000006f2;
    goto loc_10000071b;

loc_1000006f2:
    rax = realpath$DARWIN_EXTSN(r14, 0x0);
    rbx = rax;
    if (rax == 0x0) {
            *qword_1000020a0 = 0x0;
            *qword_1000020a8 = "/opt/cxoffice/lib";
            var_50 = sub_100000c00("/%s-%s", "x86_64", "unix", rcx, r8, r9, decomp_var_60);
            if (*qword_1000020a0 == 0x0) {
                    rax = sub_100000c00("%s/wine%s/ntdll.so", *qword_1000020a8, var_50, rcx, r8, r9, decomp_var_60);
                    rax = dlopen(rax, 0x2);
                    if (rax != 0x0) {
                            rax = dlsym(rax, "__wine_main");
                            if (rax != 0x0) {
                                    (rax)(r13, r12);
                            }
                            rax = fwrite("wine: __wine_main function not found in ntdll.so\n", 0x31, 0x1, **___stderrp);
                            exit(0x1);
                    }
                    var_2C = r13;
                    var_40 = r12;
                    rax = getenv("WINEDLLPATH");
                    if (rax == 0x0) {
                            rax = fprintf(**___stderrp, "wine: could not load ntdll.so: %s\n", dlerror());
                            exit(0x1);
                    }
                    rbx = rax;
                    rax = strlen(rax);
                    rax = malloc(rax + 0x1 + CARRY(RFLAGS(cf)));
                    if (rax == 0x0) {
                            rax = fwrite("Virtual memory exhausted.\n", 0x1a, 0x1, **___stderrp);
                            exit(0x1);
                    }
                    r14 = rax;
                    strcpy(rax, rbx);
                    rax = strtok(r14, ":");
                    if (rax == 0x0) {
                            free(r14);
                            rax = fprintf(**___stderrp, "wine: could not load ntdll.so: %s\n", dlerror());
                            exit(0x1);
                    }
                    r13 = rax;
                    var_58 = r14;
                    r14 = 0x0;
                    var_38 = 0x0;
                    r15 = 0x0;
                    r12 = 0x0;
                    while (true) {
                            rax = strlen(r13);
                            rcx = rax + 0x1;
                            rax = malloc(rax + 0x1 + CARRY(RFLAGS(cf)));
                            if (rax == 0x0) {
                                    temp_4 = 0x1;
                                    break;
                            }
                            rbx = rax;
                            strcpy(rax, r13);
                            if (r15 != r12) {
                                    rax = var_38;
                                    rdx = r15;
                                    r15 = r15 + 0x1;
                                    var_38 = rax;
                                    *(rax + rdx * 0x8) = rbx;
                                    rax = strtok(0x0, ":");
                                    r13 = rax;
                                    r14 = r14 + 0x2;
                                    if (rax != 0x0) {
                                            continue;
                                    }
                                    free(var_58);
                                    if (r15 != 0x0) {
                                            r12 = 0x8;
                                            r14 = "%s%s/ntdll.so";
                                            rbx = "%s/ntdll.so";
                                            temp_4 = 0x3;
                                    }
                                    else {
                                            temp_4 = 0x0;
                                    }
                                    break;
                            }
                            r12 = r14;
                            if (r15 == 0x0) {
                                    r12 = 0x10;
                            }
                            rax = realloc(var_38, r12 * 0x8);
                            if (r12 == 0x0) {
                                    rdx = r15;
                                    r15 = r15 + 0x1;
                                    var_38 = rax;
                                    *(rax + rdx * 0x8) = rbx;
                                    rax = strtok(0x0, ":");
                                    r13 = rax;
                                    r14 = r14 + 0x2;
                                    if (rax != 0x0) {
                                            continue;
                                    }
                                    free(var_58);
                                    if (r15 != 0x0) {
                                            r12 = 0x8;
                                            r14 = "%s%s/ntdll.so";
                                            rbx = "%s/ntdll.so";
                                            temp_4 = 0x3;
                                    }
                                    else {
                                            temp_4 = 0x0;
                                    }
                                    break;
                            }
                            if (rax != 0x0) {
                                    rdx = r15;
                                    r15 = r15 + 0x1;
                                    var_38 = rax;
                                    *(rax + rdx * 0x8) = rbx;
                                    rax = strtok(0x0, ":");
                                    r13 = rax;
                                    r14 = r14 + 0x2;
                                    if (rax != 0x0) {
                                            continue;
                                    }
                                    free(var_58);
                                    if (r15 != 0x0) {
                                            r12 = 0x8;
                                            r14 = "%s%s/ntdll.so";
                                            rbx = "%s/ntdll.so";
                                            temp_4 = 0x3;
                                    }
                                    else {
                                            temp_4 = 0x0;
                                    }
                                    break;
                            }
                            temp_4 = 0x2;
                            break;
                    }
                    if (temp_4 == 0x0) {
                            rax = fprintf(**___stderrp, "wine: could not load ntdll.so: %s\n", dlerror());
                            exit(0x1);
                    }
                    if (temp_4 == 0x1) {
                            rax = fwrite("Virtual memory exhausted.\n", 0x1a, 0x1, **___stderrp);
                            exit(0x1);
                    }
                    if (temp_4 == 0x2) {
                            rax = fwrite("Virtual memory exhausted.\n", 0x1a, 0x1, **___stderrp);
                            exit(0x1);
                    }
                    while (true) {
                            r13 = *(var_38 + (r12 - 0x8));
                            rdx = var_50;
                            rax = sub_100000c00(r14, r13, rdx, rcx, r8, r9, decomp_var_60);
                            rax = dlopen(rax, 0x2);
                            if (rax != 0x0) {
                                    temp_5 = 0x1;
                                    break;
                            }
                            rax = sub_100000c00(rbx, r13, rdx, rcx, r8, r9, decomp_var_60);
                            rax = dlopen(rax, 0x2);
                            if (rax != 0x0) {
                                    temp_5 = 0x1;
                                    break;
                            }
                            rax = SAR(r12, 0x3);
                            r12 = r12 + 0x8;
                            if (rax < r15) {
                                    continue;
                            }
                            temp_5 = 0x0;
                            break;
                    }
                    if (temp_5 == 0x0) {
                            rax = fprintf(**___stderrp, "wine: could not load ntdll.so: %s\n", dlerror());
                            exit(0x1);
                    }
                    r12 = var_40;
                    r13 = var_2C;
                    rax = dlsym(rax, "__wine_main");
                    if (rax != 0x0) {
                            (rax)(r13, r12);
                    }
                    rax = fwrite("wine: __wine_main function not found in ntdll.so\n", 0x31, 0x1, **___stderrp);
                    exit(0x1);
            }
            rax = strlen(*qword_1000020a0);
            if (rax >= 0xb) {
                    rax = sign_extend_32(rax);
                    if (strcmp(*qword_1000020a0 + (rax - 0xb), "/tools/wine") != 0x0) {
                            rax = sub_100000c00("%s/wine%s/ntdll.so", *qword_1000020a8, var_50, rcx, r8, r9, decomp_var_60);
                            rax = dlopen(rax, 0x2);
                            if (rax != 0x0) {
                                    rax = dlsym(rax, "__wine_main");
                                    if (rax != 0x0) {
                                            (rax)(r13, r12);
                                    }
                                    rax = fwrite("wine: __wine_main function not found in ntdll.so\n", 0x31, 0x1, **___stderrp);
                                    exit(0x1);
                            }
                            var_2C = r13;
                            var_40 = r12;
                            rax = getenv("WINEDLLPATH");
                            if (rax == 0x0) {
                                    rax = fprintf(**___stderrp, "wine: could not load ntdll.so: %s\n", dlerror());
                                    exit(0x1);
                            }
                            rbx = rax;
                            rax = strlen(rax);
                            rax = malloc(rax + 0x1 + CARRY(RFLAGS(cf)));
                            if (rax == 0x0) {
                                    rax = fwrite("Virtual memory exhausted.\n", 0x1a, 0x1, **___stderrp);
                                    exit(0x1);
                            }
                            r14 = rax;
                            strcpy(rax, rbx);
                            rax = strtok(r14, ":");
                            if (rax == 0x0) {
                                    free(r14);
                                    rax = fprintf(**___stderrp, "wine: could not load ntdll.so: %s\n", dlerror());
                                    exit(0x1);
                            }
                            r13 = rax;
                            var_58 = r14;
                            r14 = 0x0;
                            var_38 = 0x0;
                            r15 = 0x0;
                            r12 = 0x0;
                            while (true) {
                                    rax = strlen(r13);
                                    rcx = rax + 0x1;
                                    rax = malloc(rax + 0x1 + CARRY(RFLAGS(cf)));
                                    if (rax == 0x0) {
                                            temp_4 = 0x1;
                                            break;
                                    }
                                    rbx = rax;
                                    strcpy(rax, r13);
                                    if (r15 != r12) {
                                            rax = var_38;
                                            rdx = r15;
                                            r15 = r15 + 0x1;
                                            var_38 = rax;
                                            *(rax + rdx * 0x8) = rbx;
                                            rax = strtok(0x0, ":");
                                            r13 = rax;
                                            r14 = r14 + 0x2;
                                            if (rax != 0x0) {
                                                    continue;
                                            }
                                            free(var_58);
                                            if (r15 != 0x0) {
                                                    r12 = 0x8;
                                                    r14 = "%s%s/ntdll.so";
                                                    rbx = "%s/ntdll.so";
                                                    temp_4 = 0x3;
                                            }
                                            else {
                                                    temp_4 = 0x0;
                                            }
                                            break;
                                    }
                                    r12 = r14;
                                    if (r15 == 0x0) {
                                            r12 = 0x10;
                                    }
                                    rax = realloc(var_38, r12 * 0x8);
                                    if (r12 == 0x0) {
                                            rdx = r15;
                                            r15 = r15 + 0x1;
                                            var_38 = rax;
                                            *(rax + rdx * 0x8) = rbx;
                                            rax = strtok(0x0, ":");
                                            r13 = rax;
                                            r14 = r14 + 0x2;
                                            if (rax != 0x0) {
                                                    continue;
                                            }
                                            free(var_58);
                                            if (r15 != 0x0) {
                                                    r12 = 0x8;
                                                    r14 = "%s%s/ntdll.so";
                                                    rbx = "%s/ntdll.so";
                                                    temp_4 = 0x3;
                                            }
                                            else {
                                                    temp_4 = 0x0;
                                            }
                                            break;
                                    }
                                    if (rax != 0x0) {
                                            rdx = r15;
                                            r15 = r15 + 0x1;
                                            var_38 = rax;
                                            *(rax + rdx * 0x8) = rbx;
                                            rax = strtok(0x0, ":");
                                            r13 = rax;
                                            r14 = r14 + 0x2;
                                            if (rax != 0x0) {
                                                    continue;
                                            }
                                            free(var_58);
                                            if (r15 != 0x0) {
                                                    r12 = 0x8;
                                                    r14 = "%s%s/ntdll.so";
                                                    rbx = "%s/ntdll.so";
                                                    temp_4 = 0x3;
                                            }
                                            else {
                                                    temp_4 = 0x0;
                                            }
                                            break;
                                    }
                                    temp_4 = 0x2;
                                    break;
                            }
                            if (temp_4 == 0x0) {
                                    rax = fprintf(**___stderrp, "wine: could not load ntdll.so: %s\n", dlerror());
                                    exit(0x1);
                            }
                            if (temp_4 == 0x1) {
                                    rax = fwrite("Virtual memory exhausted.\n", 0x1a, 0x1, **___stderrp);
                                    exit(0x1);
                            }
                            if (temp_4 == 0x2) {
                                    rax = fwrite("Virtual memory exhausted.\n", 0x1a, 0x1, **___stderrp);
                                    exit(0x1);
                            }
                            while (true) {
                                    r13 = *(var_38 + (r12 - 0x8));
                                    rdx = var_50;
                                    rax = sub_100000c00(r14, r13, rdx, rcx, r8, r9, decomp_var_60);
                                    rax = dlopen(rax, 0x2);
                                    if (rax != 0x0) {
                                            temp_5 = 0x1;
                                            break;
                                    }
                                    rax = sub_100000c00(rbx, r13, rdx, rcx, r8, r9, decomp_var_60);
                                    rax = dlopen(rax, 0x2);
                                    if (rax != 0x0) {
                                            temp_5 = 0x1;
                                            break;
                                    }
                                    rax = SAR(r12, 0x3);
                                    r12 = r12 + 0x8;
                                    if (rax < r15) {
                                            continue;
                                    }
                                    temp_5 = 0x0;
                                    break;
                            }
                            if (temp_5 == 0x0) {
                                    rax = fprintf(**___stderrp, "wine: could not load ntdll.so: %s\n", dlerror());
                                    exit(0x1);
                            }
                            r12 = var_40;
                            r13 = var_2C;
                            rax = dlsym(rax, "__wine_main");
                            if (rax != 0x0) {
                                    (rax)(r13, r12);
                            }
                            rax = fwrite("wine: __wine_main function not found in ntdll.so\n", 0x31, 0x1, **___stderrp);
                            exit(0x1);
                    }
                    rax = sub_100000c00("%s/../../dlls/ntdll/ntdll.so", *qword_1000020a0, "unix", rcx, r8, r9, decomp_var_60);
                    rax = dlopen(rax, 0x2);
                    if (rax != 0x0) {
                            rax = dlsym(rax, "__wine_main");
                            if (rax != 0x0) {
                                    (rax)(r13, r12);
                            }
                            rax = fwrite("wine: __wine_main function not found in ntdll.so\n", 0x31, 0x1, **___stderrp);
                            exit(0x1);
                    }
                    rax = sub_100000c00("%s/wine%s/ntdll.so", *qword_1000020a8, var_50, rcx, r8, r9, decomp_var_60);
                    rax = dlopen(rax, 0x2);
                    if (rax != 0x0) {
                            rax = dlsym(rax, "__wine_main");
                            if (rax != 0x0) {
                                    (rax)(r13, r12);
                            }
                            rax = fwrite("wine: __wine_main function not found in ntdll.so\n", 0x31, 0x1, **___stderrp);
                            exit(0x1);
                    }
                    var_2C = r13;
                    var_40 = r12;
                    rax = getenv("WINEDLLPATH");
                    if (rax == 0x0) {
                            rax = fprintf(**___stderrp, "wine: could not load ntdll.so: %s\n", dlerror());
                            exit(0x1);
                    }
                    rbx = rax;
                    rax = strlen(rax);
                    rax = malloc(rax + 0x1 + CARRY(RFLAGS(cf)));
                    if (rax == 0x0) {
                            rax = fwrite("Virtual memory exhausted.\n", 0x1a, 0x1, **___stderrp);
                            exit(0x1);
                    }
                    r14 = rax;
                    strcpy(rax, rbx);
                    rax = strtok(r14, ":");
                    if (rax == 0x0) {
                            free(r14);
                            rax = fprintf(**___stderrp, "wine: could not load ntdll.so: %s\n", dlerror());
                            exit(0x1);
                    }
                    r13 = rax;
                    var_58 = r14;
                    r14 = 0x0;
                    var_38 = 0x0;
                    r15 = 0x0;
                    r12 = 0x0;
                    while (true) {
                            rax = strlen(r13);
                            rcx = rax + 0x1;
                            rax = malloc(rax + 0x1 + CARRY(RFLAGS(cf)));
                            if (rax == 0x0) {
                                    temp_4 = 0x1;
                                    break;
                            }
                            rbx = rax;
                            strcpy(rax, r13);
                            if (r15 != r12) {
                                    rax = var_38;
                                    rdx = r15;
                                    r15 = r15 + 0x1;
                                    var_38 = rax;
                                    *(rax + rdx * 0x8) = rbx;
                                    rax = strtok(0x0, ":");
                                    r13 = rax;
                                    r14 = r14 + 0x2;
                                    if (rax != 0x0) {
                                            continue;
                                    }
                                    free(var_58);
                                    if (r15 != 0x0) {
                                            r12 = 0x8;
                                            r14 = "%s%s/ntdll.so";
                                            rbx = "%s/ntdll.so";
                                            temp_4 = 0x3;
                                    }
                                    else {
                                            temp_4 = 0x0;
                                    }
                                    break;
                            }
                            r12 = r14;
                            if (r15 == 0x0) {
                                    r12 = 0x10;
                            }
                            rax = realloc(var_38, r12 * 0x8);
                            if (r12 == 0x0) {
                                    rdx = r15;
                                    r15 = r15 + 0x1;
                                    var_38 = rax;
                                    *(rax + rdx * 0x8) = rbx;
                                    rax = strtok(0x0, ":");
                                    r13 = rax;
                                    r14 = r14 + 0x2;
                                    if (rax != 0x0) {
                                            continue;
                                    }
                                    free(var_58);
                                    if (r15 != 0x0) {
                                            r12 = 0x8;
                                            r14 = "%s%s/ntdll.so";
                                            rbx = "%s/ntdll.so";
                                            temp_4 = 0x3;
                                    }
                                    else {
                                            temp_4 = 0x0;
                                    }
                                    break;
                            }
                            if (rax != 0x0) {
                                    rdx = r15;
                                    r15 = r15 + 0x1;
                                    var_38 = rax;
                                    *(rax + rdx * 0x8) = rbx;
                                    rax = strtok(0x0, ":");
                                    r13 = rax;
                                    r14 = r14 + 0x2;
                                    if (rax != 0x0) {
                                            continue;
                                    }
                                    free(var_58);
                                    if (r15 != 0x0) {
                                            r12 = 0x8;
                                            r14 = "%s%s/ntdll.so";
                                            rbx = "%s/ntdll.so";
                                            temp_4 = 0x3;
                                    }
                                    else {
                                            temp_4 = 0x0;
                                    }
                                    break;
                            }
                            temp_4 = 0x2;
                            break;
                    }
                    if (temp_4 == 0x0) {
                            rax = fprintf(**___stderrp, "wine: could not load ntdll.so: %s\n", dlerror());
                            exit(0x1);
                    }
                    if (temp_4 == 0x1) {
                            rax = fwrite("Virtual memory exhausted.\n", 0x1a, 0x1, **___stderrp);
                            exit(0x1);
                    }
                    if (temp_4 == 0x2) {
                            rax = fwrite("Virtual memory exhausted.\n", 0x1a, 0x1, **___stderrp);
                            exit(0x1);
                    }
                    while (true) {
                            r13 = *(var_38 + (r12 - 0x8));
                            rdx = var_50;
                            rax = sub_100000c00(r14, r13, rdx, rcx, r8, r9, decomp_var_60);
                            rax = dlopen(rax, 0x2);
                            if (rax != 0x0) {
                                    temp_5 = 0x1;
                                    break;
                            }
                            rax = sub_100000c00(rbx, r13, rdx, rcx, r8, r9, decomp_var_60);
                            rax = dlopen(rax, 0x2);
                            if (rax != 0x0) {
                                    temp_5 = 0x1;
                                    break;
                            }
                            rax = SAR(r12, 0x3);
                            r12 = r12 + 0x8;
                            if (rax < r15) {
                                    continue;
                            }
                            temp_5 = 0x0;
                            break;
                    }
                    if (temp_5 == 0x0) {
                            rax = fprintf(**___stderrp, "wine: could not load ntdll.so: %s\n", dlerror());
                            exit(0x1);
                    }
                    r12 = var_40;
                    r13 = var_2C;
                    rax = dlsym(rax, "__wine_main");
                    if (rax != 0x0) {
                            (rax)(r13, r12);
                    }
                    rax = fwrite("wine: __wine_main function not found in ntdll.so\n", 0x31, 0x1, **___stderrp);
                    exit(0x1);
            }
            rax = sub_100000c00("%s/wine%s/ntdll.so", *qword_1000020a8, var_50, rcx, r8, r9, decomp_var_60);
            rax = dlopen(rax, 0x2);
            if (rax != 0x0) {
                    rax = dlsym(rax, "__wine_main");
                    if (rax != 0x0) {
                            (rax)(r13, r12);
                    }
                    rax = fwrite("wine: __wine_main function not found in ntdll.so\n", 0x31, 0x1, **___stderrp);
                    exit(0x1);
            }
            var_2C = r13;
            var_40 = r12;
            rax = getenv("WINEDLLPATH");
            if (rax == 0x0) {
                    rax = fprintf(**___stderrp, "wine: could not load ntdll.so: %s\n", dlerror());
                    exit(0x1);
            }
            rbx = rax;
            rax = strlen(rax);
            rax = malloc(rax + 0x1 + CARRY(RFLAGS(cf)));
            if (rax == 0x0) {
                    rax = fwrite("Virtual memory exhausted.\n", 0x1a, 0x1, **___stderrp);
                    exit(0x1);
            }
            r14 = rax;
            strcpy(rax, rbx);
            rax = strtok(r14, ":");
            if (rax == 0x0) {
                    free(r14);
                    rax = fprintf(**___stderrp, "wine: could not load ntdll.so: %s\n", dlerror());
                    exit(0x1);
            }
            r13 = rax;
            var_58 = r14;
            r14 = 0x0;
            var_38 = 0x0;
            r15 = 0x0;
            r12 = 0x0;
            while (true) {
                    rax = strlen(r13);
                    rcx = rax + 0x1;
                    rax = malloc(rax + 0x1 + CARRY(RFLAGS(cf)));
                    if (rax == 0x0) {
                            temp_4 = 0x1;
                            break;
                    }
                    rbx = rax;
                    strcpy(rax, r13);
                    if (r15 != r12) {
                            rax = var_38;
                            rdx = r15;
                            r15 = r15 + 0x1;
                            var_38 = rax;
                            *(rax + rdx * 0x8) = rbx;
                            rax = strtok(0x0, ":");
                            r13 = rax;
                            r14 = r14 + 0x2;
                            if (rax != 0x0) {
                                    continue;
                            }
                            free(var_58);
                            if (r15 != 0x0) {
                                    r12 = 0x8;
                                    r14 = "%s%s/ntdll.so";
                                    rbx = "%s/ntdll.so";
                                    temp_4 = 0x3;
                            }
                            else {
                                    temp_4 = 0x0;
                            }
                            break;
                    }
                    r12 = r14;
                    if (r15 == 0x0) {
                            r12 = 0x10;
                    }
                    rax = realloc(var_38, r12 * 0x8);
                    if (r12 == 0x0) {
                            rdx = r15;
                            r15 = r15 + 0x1;
                            var_38 = rax;
                            *(rax + rdx * 0x8) = rbx;
                            rax = strtok(0x0, ":");
                            r13 = rax;
                            r14 = r14 + 0x2;
                            if (rax != 0x0) {
                                    continue;
                            }
                            free(var_58);
                            if (r15 != 0x0) {
                                    r12 = 0x8;
                                    r14 = "%s%s/ntdll.so";
                                    rbx = "%s/ntdll.so";
                                    temp_4 = 0x3;
                            }
                            else {
                                    temp_4 = 0x0;
                            }
                            break;
                    }
                    if (rax != 0x0) {
                            rdx = r15;
                            r15 = r15 + 0x1;
                            var_38 = rax;
                            *(rax + rdx * 0x8) = rbx;
                            rax = strtok(0x0, ":");
                            r13 = rax;
                            r14 = r14 + 0x2;
                            if (rax != 0x0) {
                                    continue;
                            }
                            free(var_58);
                            if (r15 != 0x0) {
                                    r12 = 0x8;
                                    r14 = "%s%s/ntdll.so";
                                    rbx = "%s/ntdll.so";
                                    temp_4 = 0x3;
                            }
                            else {
                                    temp_4 = 0x0;
                            }
                            break;
                    }
                    temp_4 = 0x2;
                    break;
            }
            if (temp_4 == 0x0) {
                    rax = fprintf(**___stderrp, "wine: could not load ntdll.so: %s\n", dlerror());
                    exit(0x1);
            }
            if (temp_4 == 0x1) {
                    rax = fwrite("Virtual memory exhausted.\n", 0x1a, 0x1, **___stderrp);
                    exit(0x1);
            }
            if (temp_4 == 0x2) {
                    rax = fwrite("Virtual memory exhausted.\n", 0x1a, 0x1, **___stderrp);
                    exit(0x1);
            }
            while (true) {
                    r13 = *(var_38 + (r12 - 0x8));
                    rdx = var_50;
                    rax = sub_100000c00(r14, r13, rdx, rcx, r8, r9, decomp_var_60);
                    rax = dlopen(rax, 0x2);
                    if (rax != 0x0) {
                            temp_5 = 0x1;
                            break;
                    }
                    rax = sub_100000c00(rbx, r13, rdx, rcx, r8, r9, decomp_var_60);
                    rax = dlopen(rax, 0x2);
                    if (rax != 0x0) {
                            temp_5 = 0x1;
                            break;
                    }
                    rax = SAR(r12, 0x3);
                    r12 = r12 + 0x8;
                    if (rax < r15) {
                            continue;
                    }
                    temp_5 = 0x0;
                    break;
            }
            if (temp_5 == 0x0) {
                    rax = fprintf(**___stderrp, "wine: could not load ntdll.so: %s\n", dlerror());
                    exit(0x1);
            }
            r12 = var_40;
            r13 = var_2C;
            rax = dlsym(rax, "__wine_main");
            if (rax != 0x0) {
                    (rax)(r13, r12);
            }
            rax = fwrite("wine: __wine_main function not found in ntdll.so\n", 0x31, 0x1, **___stderrp);
            exit(0x1);
    }
    goto loc_10000071b;

loc_10000071b:
    rax = strrchr(rbx, 0x2f);
    if (rax != 0x0) {
            bool_6 = rax != rbx;
            rax = sub_100000c00("%.*s", (rax == rbx ? 0x1 : 0x0) + rax - rbx, rbx, rcx, r8, r9, decomp_var_60);
            *qword_1000020a0 = rax;
            if (!bool_6) {
                    *qword_1000020a8 = "/opt/cxoffice/lib";
                    var_50 = sub_100000c00("/%s-%s", "x86_64", "unix", rcx, r8, r9, decomp_var_60);
                    if (*qword_1000020a0 != 0x0) {
                            rax = strlen(*qword_1000020a0);
                            if (rax < 0xb) {
                                    rax = sub_100000c00("%s/wine%s/ntdll.so", *qword_1000020a8, var_50, rcx, r8, r9, decomp_var_60);
                                    rax = dlopen(rax, 0x2);
                                    if (rax != 0x0) {
                                            rax = dlsym(rax, "__wine_main");
                                            if (rax != 0x0) {
                                                    (rax)(r13, r12);
                                            }
                                            rax = fwrite("wine: __wine_main function not found in ntdll.so\n", 0x31, 0x1, **___stderrp);
                                            exit(0x1);
                                    }
                                    var_2C = r13;
                                    var_40 = r12;
                                    rax = getenv("WINEDLLPATH");
                                    if (rax == 0x0) {
                                            rax = fprintf(**___stderrp, "wine: could not load ntdll.so: %s\n", dlerror());
                                            exit(0x1);
                                    }
                                    rbx = rax;
                                    rax = strlen(rax);
                                    rax = malloc(rax + 0x1 + CARRY(RFLAGS(cf)));
                                    if (rax == 0x0) {
                                            rax = fwrite("Virtual memory exhausted.\n", 0x1a, 0x1, **___stderrp);
                                            exit(0x1);
                                    }
                                    r14 = rax;
                                    strcpy(rax, rbx);
                                    rax = strtok(r14, ":");
                                    if (rax == 0x0) {
                                            free(r14);
                                            rax = fprintf(**___stderrp, "wine: could not load ntdll.so: %s\n", dlerror());
                                            exit(0x1);
                                    }
                                    r13 = rax;
                                    var_58 = r14;
                                    r14 = 0x0;
                                    var_38 = 0x0;
                                    r15 = 0x0;
                                    r12 = 0x0;
                                    while (true) {
                                            rax = strlen(r13);
                                            rcx = rax + 0x1;
                                            rax = malloc(rax + 0x1 + CARRY(RFLAGS(cf)));
                                            if (rax == 0x0) {
                                                    temp_4 = 0x1;
                                                    break;
                                            }
                                            rbx = rax;
                                            strcpy(rax, r13);
                                            if (r15 != r12) {
                                                    rax = var_38;
                                                    rdx = r15;
                                                    r15 = r15 + 0x1;
                                                    var_38 = rax;
                                                    *(rax + rdx * 0x8) = rbx;
                                                    rax = strtok(0x0, ":");
                                                    r13 = rax;
                                                    r14 = r14 + 0x2;
                                                    if (rax != 0x0) {
                                                            continue;
                                                    }
                                                    free(var_58);
                                                    if (r15 != 0x0) {
                                                            r12 = 0x8;
                                                            r14 = "%s%s/ntdll.so";
                                                            rbx = "%s/ntdll.so";
                                                            temp_4 = 0x3;
                                                    }
                                                    else {
                                                            temp_4 = 0x0;
                                                    }
                                                    break;
                                            }
                                            r12 = r14;
                                            if (r15 == 0x0) {
                                                    r12 = 0x10;
                                            }
                                            rax = realloc(var_38, r12 * 0x8);
                                            if (r12 == 0x0) {
                                                    rdx = r15;
                                                    r15 = r15 + 0x1;
                                                    var_38 = rax;
                                                    *(rax + rdx * 0x8) = rbx;
                                                    rax = strtok(0x0, ":");
                                                    r13 = rax;
                                                    r14 = r14 + 0x2;
                                                    if (rax != 0x0) {
                                                            continue;
                                                    }
                                                    free(var_58);
                                                    if (r15 != 0x0) {
                                                            r12 = 0x8;
                                                            r14 = "%s%s/ntdll.so";
                                                            rbx = "%s/ntdll.so";
                                                            temp_4 = 0x3;
                                                    }
                                                    else {
                                                            temp_4 = 0x0;
                                                    }
                                                    break;
                                            }
                                            if (rax != 0x0) {
                                                    rdx = r15;
                                                    r15 = r15 + 0x1;
                                                    var_38 = rax;
                                                    *(rax + rdx * 0x8) = rbx;
                                                    rax = strtok(0x0, ":");
                                                    r13 = rax;
                                                    r14 = r14 + 0x2;
                                                    if (rax != 0x0) {
                                                            continue;
                                                    }
                                                    free(var_58);
                                                    if (r15 != 0x0) {
                                                            r12 = 0x8;
                                                            r14 = "%s%s/ntdll.so";
                                                            rbx = "%s/ntdll.so";
                                                            temp_4 = 0x3;
                                                    }
                                                    else {
                                                            temp_4 = 0x0;
                                                    }
                                                    break;
                                            }
                                            temp_4 = 0x2;
                                            break;
                                    }
                                    if (temp_4 == 0x0) {
                                            rax = fprintf(**___stderrp, "wine: could not load ntdll.so: %s\n", dlerror());
                                            exit(0x1);
                                    }
                                    if (temp_4 == 0x1) {
                                            rax = fwrite("Virtual memory exhausted.\n", 0x1a, 0x1, **___stderrp);
                                            exit(0x1);
                                    }
                                    if (temp_4 == 0x2) {
                                            rax = fwrite("Virtual memory exhausted.\n", 0x1a, 0x1, **___stderrp);
                                            exit(0x1);
                                    }
                                    while (true) {
                                            r13 = *(var_38 + (r12 - 0x8));
                                            rdx = var_50;
                                            rax = sub_100000c00(r14, r13, rdx, rcx, r8, r9, decomp_var_60);
                                            rax = dlopen(rax, 0x2);
                                            if (rax != 0x0) {
                                                    temp_5 = 0x1;
                                                    break;
                                            }
                                            rax = sub_100000c00(rbx, r13, rdx, rcx, r8, r9, decomp_var_60);
                                            rax = dlopen(rax, 0x2);
                                            if (rax != 0x0) {
                                                    temp_5 = 0x1;
                                                    break;
                                            }
                                            rax = SAR(r12, 0x3);
                                            r12 = r12 + 0x8;
                                            if (rax < r15) {
                                                    continue;
                                            }
                                            temp_5 = 0x0;
                                            break;
                                    }
                                    if (temp_5 == 0x0) {
                                            rax = fprintf(**___stderrp, "wine: could not load ntdll.so: %s\n", dlerror());
                                            exit(0x1);
                                    }
                                    r12 = var_40;
                                    r13 = var_2C;
                                    rax = dlsym(rax, "__wine_main");
                                    if (rax != 0x0) {
                                            (rax)(r13, r12);
                                    }
                                    rax = fwrite("wine: __wine_main function not found in ntdll.so\n", 0x31, 0x1, **___stderrp);
                                    exit(0x1);
                            }
                            rbx = *qword_1000020a0;
                            rax = sign_extend_32(rax);
                            if (strcmp(*qword_1000020a0 + (rax - 0xb), "/tools/wine") != 0x0) {
                                    rax = sub_100000c00("%s/wine%s/ntdll.so", *qword_1000020a8, var_50, rcx, r8, r9, decomp_var_60);
                                    rax = dlopen(rax, 0x2);
                                    if (rax != 0x0) {
                                            rax = dlsym(rax, "__wine_main");
                                            if (rax != 0x0) {
                                                    (rax)(r13, r12);
                                            }
                                            rax = fwrite("wine: __wine_main function not found in ntdll.so\n", 0x31, 0x1, **___stderrp);
                                            exit(0x1);
                                    }
                                    var_2C = r13;
                                    var_40 = r12;
                                    rax = getenv("WINEDLLPATH");
                                    if (rax == 0x0) {
                                            rax = fprintf(**___stderrp, "wine: could not load ntdll.so: %s\n", dlerror());
                                            exit(0x1);
                                    }
                                    rbx = rax;
                                    rax = strlen(rax);
                                    rax = malloc(rax + 0x1 + CARRY(RFLAGS(cf)));
                                    if (rax == 0x0) {
                                            rax = fwrite("Virtual memory exhausted.\n", 0x1a, 0x1, **___stderrp);
                                            exit(0x1);
                                    }
                                    r14 = rax;
                                    strcpy(rax, rbx);
                                    rax = strtok(r14, ":");
                                    if (rax == 0x0) {
                                            free(r14);
                                            rax = fprintf(**___stderrp, "wine: could not load ntdll.so: %s\n", dlerror());
                                            exit(0x1);
                                    }
                                    r13 = rax;
                                    var_58 = r14;
                                    r14 = 0x0;
                                    var_38 = 0x0;
                                    r15 = 0x0;
                                    r12 = 0x0;
                                    while (true) {
                                            rax = strlen(r13);
                                            rcx = rax + 0x1;
                                            rax = malloc(rax + 0x1 + CARRY(RFLAGS(cf)));
                                            if (rax == 0x0) {
                                                    temp_4 = 0x1;
                                                    break;
                                            }
                                            rbx = rax;
                                            strcpy(rax, r13);
                                            if (r15 != r12) {
                                                    rax = var_38;
                                                    rdx = r15;
                                                    r15 = r15 + 0x1;
                                                    var_38 = rax;
                                                    *(rax + rdx * 0x8) = rbx;
                                                    rax = strtok(0x0, ":");
                                                    r13 = rax;
                                                    r14 = r14 + 0x2;
                                                    if (rax != 0x0) {
                                                            continue;
                                                    }
                                                    free(var_58);
                                                    if (r15 != 0x0) {
                                                            r12 = 0x8;
                                                            r14 = "%s%s/ntdll.so";
                                                            rbx = "%s/ntdll.so";
                                                            temp_4 = 0x3;
                                                    }
                                                    else {
                                                            temp_4 = 0x0;
                                                    }
                                                    break;
                                            }
                                            r12 = r14;
                                            if (r15 == 0x0) {
                                                    r12 = 0x10;
                                            }
                                            rax = realloc(var_38, r12 * 0x8);
                                            if (r12 == 0x0) {
                                                    rdx = r15;
                                                    r15 = r15 + 0x1;
                                                    var_38 = rax;
                                                    *(rax + rdx * 0x8) = rbx;
                                                    rax = strtok(0x0, ":");
                                                    r13 = rax;
                                                    r14 = r14 + 0x2;
                                                    if (rax != 0x0) {
                                                            continue;
                                                    }
                                                    free(var_58);
                                                    if (r15 != 0x0) {
                                                            r12 = 0x8;
                                                            r14 = "%s%s/ntdll.so";
                                                            rbx = "%s/ntdll.so";
                                                            temp_4 = 0x3;
                                                    }
                                                    else {
                                                            temp_4 = 0x0;
                                                    }
                                                    break;
                                            }
                                            if (rax != 0x0) {
                                                    rdx = r15;
                                                    r15 = r15 + 0x1;
                                                    var_38 = rax;
                                                    *(rax + rdx * 0x8) = rbx;
                                                    rax = strtok(0x0, ":");
                                                    r13 = rax;
                                                    r14 = r14 + 0x2;
                                                    if (rax != 0x0) {
                                                            continue;
                                                    }
                                                    free(var_58);
                                                    if (r15 != 0x0) {
                                                            r12 = 0x8;
                                                            r14 = "%s%s/ntdll.so";
                                                            rbx = "%s/ntdll.so";
                                                            temp_4 = 0x3;
                                                    }
                                                    else {
                                                            temp_4 = 0x0;
                                                    }
                                                    break;
                                            }
                                            temp_4 = 0x2;
                                            break;
                                    }
                                    if (temp_4 == 0x0) {
                                            rax = fprintf(**___stderrp, "wine: could not load ntdll.so: %s\n", dlerror());
                                            exit(0x1);
                                    }
                                    if (temp_4 == 0x1) {
                                            rax = fwrite("Virtual memory exhausted.\n", 0x1a, 0x1, **___stderrp);
                                            exit(0x1);
                                    }
                                    if (temp_4 == 0x2) {
                                            rax = fwrite("Virtual memory exhausted.\n", 0x1a, 0x1, **___stderrp);
                                            exit(0x1);
                                    }
                                    while (true) {
                                            r13 = *(var_38 + (r12 - 0x8));
                                            rdx = var_50;
                                            rax = sub_100000c00(r14, r13, rdx, rcx, r8, r9, decomp_var_60);
                                            rax = dlopen(rax, 0x2);
                                            if (rax != 0x0) {
                                                    temp_5 = 0x1;
                                                    break;
                                            }
                                            rax = sub_100000c00(rbx, r13, rdx, rcx, r8, r9, decomp_var_60);
                                            rax = dlopen(rax, 0x2);
                                            if (rax != 0x0) {
                                                    temp_5 = 0x1;
                                                    break;
                                            }
                                            rax = SAR(r12, 0x3);
                                            r12 = r12 + 0x8;
                                            if (rax < r15) {
                                                    continue;
                                            }
                                            temp_5 = 0x0;
                                            break;
                                    }
                                    if (temp_5 == 0x0) {
                                            rax = fprintf(**___stderrp, "wine: could not load ntdll.so: %s\n", dlerror());
                                            exit(0x1);
                                    }
                                    r12 = var_40;
                                    r13 = var_2C;
                                    rax = dlsym(rax, "__wine_main");
                                    if (rax != 0x0) {
                                            (rax)(r13, r12);
                                    }
                                    rax = fwrite("wine: __wine_main function not found in ntdll.so\n", 0x31, 0x1, **___stderrp);
                                    exit(0x1);
                            }
                            rax = sub_100000c00("%s/../../dlls/ntdll/ntdll.so", rbx, "unix", rcx, r8, r9, decomp_var_60);
                            rax = dlopen(rax, 0x2);
                            if (rax != 0x0) {
                                    rax = dlsym(rax, "__wine_main");
                                    if (rax != 0x0) {
                                            (rax)(r13, r12);
                                    }
                                    rax = fwrite("wine: __wine_main function not found in ntdll.so\n", 0x31, 0x1, **___stderrp);
                                    exit(0x1);
                            }
                            rax = sub_100000c00("%s/wine%s/ntdll.so", *qword_1000020a8, var_50, rcx, r8, r9, decomp_var_60);
                            rax = dlopen(rax, 0x2);
                            if (rax != 0x0) {
                                    rax = dlsym(rax, "__wine_main");
                                    if (rax != 0x0) {
                                            (rax)(r13, r12);
                                    }
                                    rax = fwrite("wine: __wine_main function not found in ntdll.so\n", 0x31, 0x1, **___stderrp);
                                    exit(0x1);
                            }
                            var_2C = r13;
                            var_40 = r12;
                            rax = getenv("WINEDLLPATH");
                            if (rax == 0x0) {
                                    rax = fprintf(**___stderrp, "wine: could not load ntdll.so: %s\n", dlerror());
                                    exit(0x1);
                            }
                            rbx = rax;
                            rax = strlen(rax);
                            rax = malloc(rax + 0x1 + CARRY(RFLAGS(cf)));
                            if (rax == 0x0) {
                                    rax = fwrite("Virtual memory exhausted.\n", 0x1a, 0x1, **___stderrp);
                                    exit(0x1);
                            }
                            r14 = rax;
                            strcpy(rax, rbx);
                            rax = strtok(r14, ":");
                            if (rax == 0x0) {
                                    free(r14);
                                    rax = fprintf(**___stderrp, "wine: could not load ntdll.so: %s\n", dlerror());
                                    exit(0x1);
                            }
                            r13 = rax;
                            var_58 = r14;
                            r14 = 0x0;
                            var_38 = 0x0;
                            r15 = 0x0;
                            r12 = 0x0;
                            while (true) {
                                    rax = strlen(r13);
                                    rcx = rax + 0x1;
                                    rax = malloc(rax + 0x1 + CARRY(RFLAGS(cf)));
                                    if (rax == 0x0) {
                                            temp_4 = 0x1;
                                            break;
                                    }
                                    rbx = rax;
                                    strcpy(rax, r13);
                                    if (r15 != r12) {
                                            rax = var_38;
                                            rdx = r15;
                                            r15 = r15 + 0x1;
                                            var_38 = rax;
                                            *(rax + rdx * 0x8) = rbx;
                                            rax = strtok(0x0, ":");
                                            r13 = rax;
                                            r14 = r14 + 0x2;
                                            if (rax != 0x0) {
                                                    continue;
                                            }
                                            free(var_58);
                                            if (r15 != 0x0) {
                                                    r12 = 0x8;
                                                    r14 = "%s%s/ntdll.so";
                                                    rbx = "%s/ntdll.so";
                                                    temp_4 = 0x3;
                                            }
                                            else {
                                                    temp_4 = 0x0;
                                            }
                                            break;
                                    }
                                    r12 = r14;
                                    if (r15 == 0x0) {
                                            r12 = 0x10;
                                    }
                                    rax = realloc(var_38, r12 * 0x8);
                                    if (r12 == 0x0) {
                                            rdx = r15;
                                            r15 = r15 + 0x1;
                                            var_38 = rax;
                                            *(rax + rdx * 0x8) = rbx;
                                            rax = strtok(0x0, ":");
                                            r13 = rax;
                                            r14 = r14 + 0x2;
                                            if (rax != 0x0) {
                                                    continue;
                                            }
                                            free(var_58);
                                            if (r15 != 0x0) {
                                                    r12 = 0x8;
                                                    r14 = "%s%s/ntdll.so";
                                                    rbx = "%s/ntdll.so";
                                                    temp_4 = 0x3;
                                            }
                                            else {
                                                    temp_4 = 0x0;
                                            }
                                            break;
                                    }
                                    if (rax != 0x0) {
                                            rdx = r15;
                                            r15 = r15 + 0x1;
                                            var_38 = rax;
                                            *(rax + rdx * 0x8) = rbx;
                                            rax = strtok(0x0, ":");
                                            r13 = rax;
                                            r14 = r14 + 0x2;
                                            if (rax != 0x0) {
                                                    continue;
                                            }
                                            free(var_58);
                                            if (r15 != 0x0) {
                                                    r12 = 0x8;
                                                    r14 = "%s%s/ntdll.so";
                                                    rbx = "%s/ntdll.so";
                                                    temp_4 = 0x3;
                                            }
                                            else {
                                                    temp_4 = 0x0;
                                            }
                                            break;
                                    }
                                    temp_4 = 0x2;
                                    break;
                            }
                            if (temp_4 == 0x0) {
                                    rax = fprintf(**___stderrp, "wine: could not load ntdll.so: %s\n", dlerror());
                                    exit(0x1);
                            }
                            if (temp_4 == 0x1) {
                                    rax = fwrite("Virtual memory exhausted.\n", 0x1a, 0x1, **___stderrp);
                                    exit(0x1);
                            }
                            if (temp_4 == 0x2) {
                                    rax = fwrite("Virtual memory exhausted.\n", 0x1a, 0x1, **___stderrp);
                                    exit(0x1);
                            }
                            while (true) {
                                    r13 = *(var_38 + (r12 - 0x8));
                                    rdx = var_50;
                                    rax = sub_100000c00(r14, r13, rdx, rcx, r8, r9, decomp_var_60);
                                    rax = dlopen(rax, 0x2);
                                    if (rax != 0x0) {
                                            temp_5 = 0x1;
                                            break;
                                    }
                                    rax = sub_100000c00(rbx, r13, rdx, rcx, r8, r9, decomp_var_60);
                                    rax = dlopen(rax, 0x2);
                                    if (rax != 0x0) {
                                            temp_5 = 0x1;
                                            break;
                                    }
                                    rax = SAR(r12, 0x3);
                                    r12 = r12 + 0x8;
                                    if (rax < r15) {
                                            continue;
                                    }
                                    temp_5 = 0x0;
                                    break;
                            }
                            if (temp_5 == 0x0) {
                                    rax = fprintf(**___stderrp, "wine: could not load ntdll.so: %s\n", dlerror());
                                    exit(0x1);
                            }
                            r12 = var_40;
                            r13 = var_2C;
                            rax = dlsym(rax, "__wine_main");
                            if (rax != 0x0) {
                                    (rax)(r13, r12);
                            }
                            rax = fwrite("wine: __wine_main function not found in ntdll.so\n", 0x31, 0x1, **___stderrp);
                            exit(0x1);
                    }
                    rax = sub_100000c00("%s/wine%s/ntdll.so", *qword_1000020a8, var_50, rcx, r8, r9, decomp_var_60);
                    rax = dlopen(rax, 0x2);
                    if (rax != 0x0) {
                            rax = dlsym(rax, "__wine_main");
                            if (rax != 0x0) {
                                    (rax)(r13, r12);
                            }
                            rax = fwrite("wine: __wine_main function not found in ntdll.so\n", 0x31, 0x1, **___stderrp);
                            exit(0x1);
                    }
                    var_2C = r13;
                    var_40 = r12;
                    rax = getenv("WINEDLLPATH");
                    if (rax == 0x0) {
                            rax = fprintf(**___stderrp, "wine: could not load ntdll.so: %s\n", dlerror());
                            exit(0x1);
                    }
                    rbx = rax;
                    rax = strlen(rax);
                    rax = malloc(rax + 0x1 + CARRY(RFLAGS(cf)));
                    if (rax == 0x0) {
                            rax = fwrite("Virtual memory exhausted.\n", 0x1a, 0x1, **___stderrp);
                            exit(0x1);
                    }
                    r14 = rax;
                    strcpy(rax, rbx);
                    rax = strtok(r14, ":");
                    if (rax == 0x0) {
                            free(r14);
                            rax = fprintf(**___stderrp, "wine: could not load ntdll.so: %s\n", dlerror());
                            exit(0x1);
                    }
                    r13 = rax;
                    var_58 = r14;
                    r14 = 0x0;
                    var_38 = 0x0;
                    r15 = 0x0;
                    r12 = 0x0;
                    while (true) {
                            rax = strlen(r13);
                            rcx = rax + 0x1;
                            rax = malloc(rax + 0x1 + CARRY(RFLAGS(cf)));
                            if (rax == 0x0) {
                                    temp_4 = 0x1;
                                    break;
                            }
                            rbx = rax;
                            strcpy(rax, r13);
                            if (r15 != r12) {
                                    rax = var_38;
                                    rdx = r15;
                                    r15 = r15 + 0x1;
                                    var_38 = rax;
                                    *(rax + rdx * 0x8) = rbx;
                                    rax = strtok(0x0, ":");
                                    r13 = rax;
                                    r14 = r14 + 0x2;
                                    if (rax != 0x0) {
                                            continue;
                                    }
                                    free(var_58);
                                    if (r15 != 0x0) {
                                            r12 = 0x8;
                                            r14 = "%s%s/ntdll.so";
                                            rbx = "%s/ntdll.so";
                                            temp_4 = 0x3;
                                    }
                                    else {
                                            temp_4 = 0x0;
                                    }
                                    break;
                            }
                            r12 = r14;
                            if (r15 == 0x0) {
                                    r12 = 0x10;
                            }
                            rax = realloc(var_38, r12 * 0x8);
                            if (r12 == 0x0) {
                                    rdx = r15;
                                    r15 = r15 + 0x1;
                                    var_38 = rax;
                                    *(rax + rdx * 0x8) = rbx;
                                    rax = strtok(0x0, ":");
                                    r13 = rax;
                                    r14 = r14 + 0x2;
                                    if (rax != 0x0) {
                                            continue;
                                    }
                                    free(var_58);
                                    if (r15 != 0x0) {
                                            r12 = 0x8;
                                            r14 = "%s%s/ntdll.so";
                                            rbx = "%s/ntdll.so";
                                            temp_4 = 0x3;
                                    }
                                    else {
                                            temp_4 = 0x0;
                                    }
                                    break;
                            }
                            if (rax != 0x0) {
                                    rdx = r15;
                                    r15 = r15 + 0x1;
                                    var_38 = rax;
                                    *(rax + rdx * 0x8) = rbx;
                                    rax = strtok(0x0, ":");
                                    r13 = rax;
                                    r14 = r14 + 0x2;
                                    if (rax != 0x0) {
                                            continue;
                                    }
                                    free(var_58);
                                    if (r15 != 0x0) {
                                            r12 = 0x8;
                                            r14 = "%s%s/ntdll.so";
                                            rbx = "%s/ntdll.so";
                                            temp_4 = 0x3;
                                    }
                                    else {
                                            temp_4 = 0x0;
                                    }
                                    break;
                            }
                            temp_4 = 0x2;
                            break;
                    }
                    if (temp_4 == 0x0) {
                            rax = fprintf(**___stderrp, "wine: could not load ntdll.so: %s\n", dlerror());
                            exit(0x1);
                    }
                    if (temp_4 == 0x1) {
                            rax = fwrite("Virtual memory exhausted.\n", 0x1a, 0x1, **___stderrp);
                            exit(0x1);
                    }
                    if (temp_4 == 0x2) {
                            rax = fwrite("Virtual memory exhausted.\n", 0x1a, 0x1, **___stderrp);
                            exit(0x1);
                    }
                    while (true) {
                            r13 = *(var_38 + (r12 - 0x8));
                            rdx = var_50;
                            rax = sub_100000c00(r14, r13, rdx, rcx, r8, r9, decomp_var_60);
                            rax = dlopen(rax, 0x2);
                            if (rax != 0x0) {
                                    temp_5 = 0x1;
                                    break;
                            }
                            rax = sub_100000c00(rbx, r13, rdx, rcx, r8, r9, decomp_var_60);
                            rax = dlopen(rax, 0x2);
                            if (rax != 0x0) {
                                    temp_5 = 0x1;
                                    break;
                            }
                            rax = SAR(r12, 0x3);
                            r12 = r12 + 0x8;
                            if (rax < r15) {
                                    continue;
                            }
                            temp_5 = 0x0;
                            break;
                    }
                    if (temp_5 == 0x0) {
                            rax = fprintf(**___stderrp, "wine: could not load ntdll.so: %s\n", dlerror());
                            exit(0x1);
                    }
                    r12 = var_40;
                    r13 = var_2C;
                    rax = dlsym(rax, "__wine_main");
                    if (rax != 0x0) {
                            (rax)(r13, r12);
                    }
                    rax = fwrite("wine: __wine_main function not found in ntdll.so\n", 0x31, 0x1, **___stderrp);
                    exit(0x1);
            }
            var_2C = r13;
            var_40 = r12;
            rdi = "/opt/cxoffice/bin";
            rdx = "/opt/cxoffice/lib";
            while (true) {
                    rdi = rdi - 0x1;
                    do {
                            rcx = rdi[0x1] & 0xff;
                            rdi = rdi + 0x1;
                    } while (rcx == 0x2f);
                    r12 = rdx - 0x1;
                    do {
                            r13 = r12[0x1] & 0xff;
                            r12 = r12 + 0x1;
                    } while (r13 == 0x2f);
                    if (rcx == 0x0) {
                            r15 = 0x0;
                            temp_2 = 0x1;
                            break;
                    }
                    rdx = r12;
                    if (rcx == 0x0) {
                            rsi = *(int8_t *)rdx & 0xff;
                            if (rsi == 0x0) {
                                    continue;
                            }
                            if ((rsi & 0xff) == 0x2f) {
                                    continue;
                            }
                            temp_2 = 0x0;
                            break;
                    }
                    while (true) {
                            rsi = rcx & 0xff;
                            if (rsi == 0x2f) {
                                    temp_0 = 0x1;
                                    break;
                            }
                            rsi = *(int8_t *)rdx & 0xff;
                            if (rcx != rsi) {
                                    temp_0 = 0x2;
                                    break;
                            }
                            rdx = rdx + 0x1;
                            rcx = rdi[0x1] & 0xff;
                            rdi = rdi + 0x1;
                            if (rcx != 0x0) {
                                    continue;
                            }
                            temp_0 = 0x0;
                            break;
                    }
                    if (temp_0 == 0x0) {
                            rsi = *(int8_t *)rdx & 0xff;
                            if (rsi == 0x0) {
                                    continue;
                            }
                            if ((rsi & 0xff) == 0x2f) {
                                    continue;
                            }
                            temp_2 = 0x0;
                            break;
                    }
                    if (temp_0 == 0x1) {
                            rsi = *(int8_t *)rdx & 0xff;
                            if (rsi == 0x0) {
                                    continue;
                            }
                            if ((rsi & 0xff) == 0x2f) {
                                    continue;
                            }
                            temp_2 = 0x0;
                            break;
                    }
                    if (rcx != 0x0) {
                            temp_2 = 0x0;
                            break;
                    }
                    if (rsi == 0x0) {
                            continue;
                    }
                    if ((rsi & 0xff) == 0x2f) {
                            continue;
                    }
                    temp_2 = 0x0;
                    break;
            }
            if (temp_2 == 0x0) {
                    r15 = 0x0;
                    temp_3 = 0x4;
                    while (true) {
                            if (temp_3 == 0x4) {
                                    r15 = r15 + 0x1;
                                    if (rcx != 0x2f) {
                                            while (true) {
                                                    rcx = rcx & 0xff;
                                                    if (rcx == 0x0) {
                                                            temp_1 = 0x0;
                                                            break;
                                                    }
                                                    rcx = rdi[0x1] & 0xff;
                                                    rdi = rdi + 0x1;
                                                    if (rcx != 0x2f) {
                                                            continue;
                                                    }
                                                    temp_1 = 0x1;
                                                    break;
                                            }
                                            temp_3 = 0x8;
                                            continue;
                                    }
                                    rcx = *(int8_t *)rdi & 0xff;
                                    if (rcx == 0x2f) {
                                            rdi = rdi + 0x1;
                                            temp_3 = 0x8;
                                            continue;
                                    }
                                    if (rcx != 0x0) {
                                            temp_3 = 0x4;
                                            continue;
                                    }
                                    break;
                            }
                            rcx = *(int8_t *)rdi & 0xff;
                            if (rcx == 0x2f) {
                                    rdi = rdi + 0x1;
                                    temp_3 = 0x8;
                                    continue;
                            }
                            if (rcx == 0x0) {
                                    break;
                            }
                            temp_3 = 0x4;
                    }
            }
            var_38 = rax;
            rbx = strlen(rax);
            rax = strlen(r12);
            rax = malloc(r15 + r15 * 0x2 + rbx + rax + 0x2 + CARRY(RFLAGS(cf)));
            if (rax == 0x0) {
                    rax = fwrite("Virtual memory exhausted.\n", 0x1a, 0x1, **___stderrp);
                    exit(0x1);
            }
            r14 = rax;
            strcpy(rax, var_38);
            if (r15 != 0x0) {
                    do {
                            *(int32_t *)(r14 + strlen(r14)) = 0x2e2e2f;
                            r15 = r15 - 0x1;
                    } while (r15 != 0x0);
            }
            if (r13 != 0x0) {
                    *(int16_t *)(r14 + strlen(r14)) = 0x2f;
                    strcat(r14, r12);
            }
            r12 = var_40;
            r13 = var_2C;
            *qword_1000020a8 = r14;
            var_50 = sub_100000c00("/%s-%s", "x86_64", "unix", rcx, r8, r9, decomp_var_60);
            if (*qword_1000020a0 != 0x0) {
                    rax = strlen(*qword_1000020a0);
                    if (rax >= 0xb) {
                            rax = sign_extend_32(rax);
                            if (strcmp(*qword_1000020a0 + (rax - 0xb), "/tools/wine") == 0x0) {
                                    rax = sub_100000c00("%s/../../dlls/ntdll/ntdll.so", *qword_1000020a0, "unix", rcx, r8, r9, decomp_var_60);
                                    rax = dlopen(rax, 0x2);
                                    if (rax != 0x0) {
                                            rax = dlsym(rax, "__wine_main");
                                            if (rax != 0x0) {
                                                    (rax)(r13, r12);
                                            }
                                            rax = fwrite("wine: __wine_main function not found in ntdll.so\n", 0x31, 0x1, **___stderrp);
                                            exit(0x1);
                                    }
                                    rax = sub_100000c00("%s/wine%s/ntdll.so", *qword_1000020a8, var_50, rcx, r8, r9, decomp_var_60);
                                    rax = dlopen(rax, 0x2);
                                    if (rax != 0x0) {
                                            rax = dlsym(rax, "__wine_main");
                                            if (rax != 0x0) {
                                                    (rax)(r13, r12);
                                            }
                                            rax = fwrite("wine: __wine_main function not found in ntdll.so\n", 0x31, 0x1, **___stderrp);
                                            exit(0x1);
                                    }
                                    var_2C = r13;
                                    var_40 = r12;
                                    rax = getenv("WINEDLLPATH");
                                    if (rax == 0x0) {
                                            rax = fprintf(**___stderrp, "wine: could not load ntdll.so: %s\n", dlerror());
                                            exit(0x1);
                                    }
                                    rbx = rax;
                                    rax = strlen(rax);
                                    rax = malloc(rax + 0x1 + CARRY(RFLAGS(cf)));
                                    if (rax == 0x0) {
                                            rax = fwrite("Virtual memory exhausted.\n", 0x1a, 0x1, **___stderrp);
                                            exit(0x1);
                                    }
                                    r14 = rax;
                                    strcpy(rax, rbx);
                                    rax = strtok(r14, ":");
                                    if (rax == 0x0) {
                                            free(r14);
                                            rax = fprintf(**___stderrp, "wine: could not load ntdll.so: %s\n", dlerror());
                                            exit(0x1);
                                    }
                                    r13 = rax;
                                    var_58 = r14;
                                    r14 = 0x0;
                                    var_38 = 0x0;
                                    r15 = 0x0;
                                    r12 = 0x0;
                                    while (true) {
                                            rax = strlen(r13);
                                            rcx = rax + 0x1;
                                            rax = malloc(rax + 0x1 + CARRY(RFLAGS(cf)));
                                            if (rax == 0x0) {
                                                    temp_4 = 0x1;
                                                    break;
                                            }
                                            rbx = rax;
                                            strcpy(rax, r13);
                                            if (r15 != r12) {
                                                    rax = var_38;
                                                    rdx = r15;
                                                    r15 = r15 + 0x1;
                                                    var_38 = rax;
                                                    *(rax + rdx * 0x8) = rbx;
                                                    rax = strtok(0x0, ":");
                                                    r13 = rax;
                                                    r14 = r14 + 0x2;
                                                    if (rax != 0x0) {
                                                            continue;
                                                    }
                                                    free(var_58);
                                                    if (r15 != 0x0) {
                                                            r12 = 0x8;
                                                            r14 = "%s%s/ntdll.so";
                                                            rbx = "%s/ntdll.so";
                                                            temp_4 = 0x3;
                                                    }
                                                    else {
                                                            temp_4 = 0x0;
                                                    }
                                                    break;
                                            }
                                            r12 = r14;
                                            if (r15 == 0x0) {
                                                    r12 = 0x10;
                                            }
                                            rax = realloc(var_38, r12 * 0x8);
                                            if (r12 == 0x0) {
                                                    rdx = r15;
                                                    r15 = r15 + 0x1;
                                                    var_38 = rax;
                                                    *(rax + rdx * 0x8) = rbx;
                                                    rax = strtok(0x0, ":");
                                                    r13 = rax;
                                                    r14 = r14 + 0x2;
                                                    if (rax != 0x0) {
                                                            continue;
                                                    }
                                                    free(var_58);
                                                    if (r15 != 0x0) {
                                                            r12 = 0x8;
                                                            r14 = "%s%s/ntdll.so";
                                                            rbx = "%s/ntdll.so";
                                                            temp_4 = 0x3;
                                                    }
                                                    else {
                                                            temp_4 = 0x0;
                                                    }
                                                    break;
                                            }
                                            if (rax != 0x0) {
                                                    rdx = r15;
                                                    r15 = r15 + 0x1;
                                                    var_38 = rax;
                                                    *(rax + rdx * 0x8) = rbx;
                                                    rax = strtok(0x0, ":");
                                                    r13 = rax;
                                                    r14 = r14 + 0x2;
                                                    if (rax != 0x0) {
                                                            continue;
                                                    }
                                                    free(var_58);
                                                    if (r15 != 0x0) {
                                                            r12 = 0x8;
                                                            r14 = "%s%s/ntdll.so";
                                                            rbx = "%s/ntdll.so";
                                                            temp_4 = 0x3;
                                                    }
                                                    else {
                                                            temp_4 = 0x0;
                                                    }
                                                    break;
                                            }
                                            temp_4 = 0x2;
                                            break;
                                    }
                                    if (temp_4 == 0x0) {
                                            rax = fprintf(**___stderrp, "wine: could not load ntdll.so: %s\n", dlerror());
                                            exit(0x1);
                                    }
                                    if (temp_4 == 0x1) {
                                            rax = fwrite("Virtual memory exhausted.\n", 0x1a, 0x1, **___stderrp);
                                            exit(0x1);
                                    }
                                    if (temp_4 == 0x2) {
                                            rax = fwrite("Virtual memory exhausted.\n", 0x1a, 0x1, **___stderrp);
                                            exit(0x1);
                                    }
                                    while (true) {
                                            r13 = *(var_38 + (r12 - 0x8));
                                            rdx = var_50;
                                            rax = sub_100000c00(r14, r13, rdx, rcx, r8, r9, decomp_var_60);
                                            rax = dlopen(rax, 0x2);
                                            if (rax != 0x0) {
                                                    temp_5 = 0x1;
                                                    break;
                                            }
                                            rax = sub_100000c00(rbx, r13, rdx, rcx, r8, r9, decomp_var_60);
                                            rax = dlopen(rax, 0x2);
                                            if (rax != 0x0) {
                                                    temp_5 = 0x1;
                                                    break;
                                            }
                                            rax = SAR(r12, 0x3);
                                            r12 = r12 + 0x8;
                                            if (rax < r15) {
                                                    continue;
                                            }
                                            temp_5 = 0x0;
                                            break;
                                    }
                                    if (temp_5 == 0x0) {
                                            rax = fprintf(**___stderrp, "wine: could not load ntdll.so: %s\n", dlerror());
                                            exit(0x1);
                                    }
                                    r12 = var_40;
                                    r13 = var_2C;
                                    rax = dlsym(rax, "__wine_main");
                                    if (rax != 0x0) {
                                            (rax)(r13, r12);
                                    }
                                    rax = fwrite("wine: __wine_main function not found in ntdll.so\n", 0x31, 0x1, **___stderrp);
                                    exit(0x1);
                            }
                            rax = sub_100000c00("%s/wine%s/ntdll.so", *qword_1000020a8, var_50, rcx, r8, r9, decomp_var_60);
                            rax = dlopen(rax, 0x2);
                            if (rax != 0x0) {
                                    rax = dlsym(rax, "__wine_main");
                                    if (rax != 0x0) {
                                            (rax)(r13, r12);
                                    }
                                    rax = fwrite("wine: __wine_main function not found in ntdll.so\n", 0x31, 0x1, **___stderrp);
                                    exit(0x1);
                            }
                            var_2C = r13;
                            var_40 = r12;
                            rax = getenv("WINEDLLPATH");
                            if (rax == 0x0) {
                                    rax = fprintf(**___stderrp, "wine: could not load ntdll.so: %s\n", dlerror());
                                    exit(0x1);
                            }
                            rbx = rax;
                            rax = strlen(rax);
                            rax = malloc(rax + 0x1 + CARRY(RFLAGS(cf)));
                            if (rax == 0x0) {
                                    rax = fwrite("Virtual memory exhausted.\n", 0x1a, 0x1, **___stderrp);
                                    exit(0x1);
                            }
                            r14 = rax;
                            strcpy(rax, rbx);
                            rax = strtok(r14, ":");
                            if (rax == 0x0) {
                                    free(r14);
                                    rax = fprintf(**___stderrp, "wine: could not load ntdll.so: %s\n", dlerror());
                                    exit(0x1);
                            }
                            r13 = rax;
                            var_58 = r14;
                            r14 = 0x0;
                            var_38 = 0x0;
                            r15 = 0x0;
                            r12 = 0x0;
                            while (true) {
                                    rax = strlen(r13);
                                    rcx = rax + 0x1;
                                    rax = malloc(rax + 0x1 + CARRY(RFLAGS(cf)));
                                    if (rax == 0x0) {
                                            temp_4 = 0x1;
                                            break;
                                    }
                                    rbx = rax;
                                    strcpy(rax, r13);
                                    if (r15 != r12) {
                                            rax = var_38;
                                            rdx = r15;
                                            r15 = r15 + 0x1;
                                            var_38 = rax;
                                            *(rax + rdx * 0x8) = rbx;
                                            rax = strtok(0x0, ":");
                                            r13 = rax;
                                            r14 = r14 + 0x2;
                                            if (rax != 0x0) {
                                                    continue;
                                            }
                                            free(var_58);
                                            if (r15 != 0x0) {
                                                    r12 = 0x8;
                                                    r14 = "%s%s/ntdll.so";
                                                    rbx = "%s/ntdll.so";
                                                    temp_4 = 0x3;
                                            }
                                            else {
                                                    temp_4 = 0x0;
                                            }
                                            break;
                                    }
                                    r12 = r14;
                                    if (r15 == 0x0) {
                                            r12 = 0x10;
                                    }
                                    rax = realloc(var_38, r12 * 0x8);
                                    if (r12 == 0x0) {
                                            rdx = r15;
                                            r15 = r15 + 0x1;
                                            var_38 = rax;
                                            *(rax + rdx * 0x8) = rbx;
                                            rax = strtok(0x0, ":");
                                            r13 = rax;
                                            r14 = r14 + 0x2;
                                            if (rax != 0x0) {
                                                    continue;
                                            }
                                            free(var_58);
                                            if (r15 != 0x0) {
                                                    r12 = 0x8;
                                                    r14 = "%s%s/ntdll.so";
                                                    rbx = "%s/ntdll.so";
                                                    temp_4 = 0x3;
                                            }
                                            else {
                                                    temp_4 = 0x0;
                                            }
                                            break;
                                    }
                                    if (rax != 0x0) {
                                            rdx = r15;
                                            r15 = r15 + 0x1;
                                            var_38 = rax;
                                            *(rax + rdx * 0x8) = rbx;
                                            rax = strtok(0x0, ":");
                                            r13 = rax;
                                            r14 = r14 + 0x2;
                                            if (rax != 0x0) {
                                                    continue;
                                            }
                                            free(var_58);
                                            if (r15 != 0x0) {
                                                    r12 = 0x8;
                                                    r14 = "%s%s/ntdll.so";
                                                    rbx = "%s/ntdll.so";
                                                    temp_4 = 0x3;
                                            }
                                            else {
                                                    temp_4 = 0x0;
                                            }
                                            break;
                                    }
                                    temp_4 = 0x2;
                                    break;
                            }
                            if (temp_4 == 0x0) {
                                    rax = fprintf(**___stderrp, "wine: could not load ntdll.so: %s\n", dlerror());
                                    exit(0x1);
                            }
                            if (temp_4 == 0x1) {
                                    rax = fwrite("Virtual memory exhausted.\n", 0x1a, 0x1, **___stderrp);
                                    exit(0x1);
                            }
                            if (temp_4 == 0x2) {
                                    rax = fwrite("Virtual memory exhausted.\n", 0x1a, 0x1, **___stderrp);
                                    exit(0x1);
                            }
                            while (true) {
                                    r13 = *(var_38 + (r12 - 0x8));
                                    rdx = var_50;
                                    rax = sub_100000c00(r14, r13, rdx, rcx, r8, r9, decomp_var_60);
                                    rax = dlopen(rax, 0x2);
                                    if (rax != 0x0) {
                                            temp_5 = 0x1;
                                            break;
                                    }
                                    rax = sub_100000c00(rbx, r13, rdx, rcx, r8, r9, decomp_var_60);
                                    rax = dlopen(rax, 0x2);
                                    if (rax != 0x0) {
                                            temp_5 = 0x1;
                                            break;
                                    }
                                    rax = SAR(r12, 0x3);
                                    r12 = r12 + 0x8;
                                    if (rax < r15) {
                                            continue;
                                    }
                                    temp_5 = 0x0;
                                    break;
                            }
                            if (temp_5 == 0x0) {
                                    rax = fprintf(**___stderrp, "wine: could not load ntdll.so: %s\n", dlerror());
                                    exit(0x1);
                            }
                            r12 = var_40;
                            r13 = var_2C;
                            rax = dlsym(rax, "__wine_main");
                            if (rax != 0x0) {
                                    (rax)(r13, r12);
                            }
                            rax = fwrite("wine: __wine_main function not found in ntdll.so\n", 0x31, 0x1, **___stderrp);
                            exit(0x1);
                    }
                    rax = sub_100000c00("%s/wine%s/ntdll.so", *qword_1000020a8, var_50, rcx, r8, r9, decomp_var_60);
                    rax = dlopen(rax, 0x2);
                    if (rax != 0x0) {
                            rax = dlsym(rax, "__wine_main");
                            if (rax != 0x0) {
                                    (rax)(r13, r12);
                            }
                            rax = fwrite("wine: __wine_main function not found in ntdll.so\n", 0x31, 0x1, **___stderrp);
                            exit(0x1);
                    }
                    var_2C = r13;
                    var_40 = r12;
                    rax = getenv("WINEDLLPATH");
                    if (rax == 0x0) {
                            rax = fprintf(**___stderrp, "wine: could not load ntdll.so: %s\n", dlerror());
                            exit(0x1);
                    }
                    rbx = rax;
                    rax = strlen(rax);
                    rax = malloc(rax + 0x1 + CARRY(RFLAGS(cf)));
                    if (rax == 0x0) {
                            rax = fwrite("Virtual memory exhausted.\n", 0x1a, 0x1, **___stderrp);
                            exit(0x1);
                    }
                    r14 = rax;
                    strcpy(rax, rbx);
                    rax = strtok(r14, ":");
                    if (rax == 0x0) {
                            free(r14);
                            rax = fprintf(**___stderrp, "wine: could not load ntdll.so: %s\n", dlerror());
                            exit(0x1);
                    }
                    r13 = rax;
                    var_58 = r14;
                    r14 = 0x0;
                    var_38 = 0x0;
                    r15 = 0x0;
                    r12 = 0x0;
                    while (true) {
                            rax = strlen(r13);
                            rcx = rax + 0x1;
                            rax = malloc(rax + 0x1 + CARRY(RFLAGS(cf)));
                            if (rax == 0x0) {
                                    temp_4 = 0x1;
                                    break;
                            }
                            rbx = rax;
                            strcpy(rax, r13);
                            if (r15 != r12) {
                                    rax = var_38;
                                    rdx = r15;
                                    r15 = r15 + 0x1;
                                    var_38 = rax;
                                    *(rax + rdx * 0x8) = rbx;
                                    rax = strtok(0x0, ":");
                                    r13 = rax;
                                    r14 = r14 + 0x2;
                                    if (rax != 0x0) {
                                            continue;
                                    }
                                    free(var_58);
                                    if (r15 != 0x0) {
                                            r12 = 0x8;
                                            r14 = "%s%s/ntdll.so";
                                            rbx = "%s/ntdll.so";
                                            temp_4 = 0x3;
                                    }
                                    else {
                                            temp_4 = 0x0;
                                    }
                                    break;
                            }
                            r12 = r14;
                            if (r15 == 0x0) {
                                    r12 = 0x10;
                            }
                            rax = realloc(var_38, r12 * 0x8);
                            if (r12 == 0x0) {
                                    rdx = r15;
                                    r15 = r15 + 0x1;
                                    var_38 = rax;
                                    *(rax + rdx * 0x8) = rbx;
                                    rax = strtok(0x0, ":");
                                    r13 = rax;
                                    r14 = r14 + 0x2;
                                    if (rax != 0x0) {
                                            continue;
                                    }
                                    free(var_58);
                                    if (r15 != 0x0) {
                                            r12 = 0x8;
                                            r14 = "%s%s/ntdll.so";
                                            rbx = "%s/ntdll.so";
                                            temp_4 = 0x3;
                                    }
                                    else {
                                            temp_4 = 0x0;
                                    }
                                    break;
                            }
                            if (rax != 0x0) {
                                    rdx = r15;
                                    r15 = r15 + 0x1;
                                    var_38 = rax;
                                    *(rax + rdx * 0x8) = rbx;
                                    rax = strtok(0x0, ":");
                                    r13 = rax;
                                    r14 = r14 + 0x2;
                                    if (rax != 0x0) {
                                            continue;
                                    }
                                    free(var_58);
                                    if (r15 != 0x0) {
                                            r12 = 0x8;
                                            r14 = "%s%s/ntdll.so";
                                            rbx = "%s/ntdll.so";
                                            temp_4 = 0x3;
                                    }
                                    else {
                                            temp_4 = 0x0;
                                    }
                                    break;
                            }
                            temp_4 = 0x2;
                            break;
                    }
                    if (temp_4 == 0x0) {
                            rax = fprintf(**___stderrp, "wine: could not load ntdll.so: %s\n", dlerror());
                            exit(0x1);
                    }
                    if (temp_4 == 0x1) {
                            rax = fwrite("Virtual memory exhausted.\n", 0x1a, 0x1, **___stderrp);
                            exit(0x1);
                    }
                    if (temp_4 == 0x2) {
                            rax = fwrite("Virtual memory exhausted.\n", 0x1a, 0x1, **___stderrp);
                            exit(0x1);
                    }
                    while (true) {
                            r13 = *(var_38 + (r12 - 0x8));
                            rdx = var_50;
                            rax = sub_100000c00(r14, r13, rdx, rcx, r8, r9, decomp_var_60);
                            rax = dlopen(rax, 0x2);
                            if (rax != 0x0) {
                                    temp_5 = 0x1;
                                    break;
                            }
                            rax = sub_100000c00(rbx, r13, rdx, rcx, r8, r9, decomp_var_60);
                            rax = dlopen(rax, 0x2);
                            if (rax != 0x0) {
                                    temp_5 = 0x1;
                                    break;
                            }
                            rax = SAR(r12, 0x3);
                            r12 = r12 + 0x8;
                            if (rax < r15) {
                                    continue;
                            }
                            temp_5 = 0x0;
                            break;
                    }
                    if (temp_5 == 0x0) {
                            rax = fprintf(**___stderrp, "wine: could not load ntdll.so: %s\n", dlerror());
                            exit(0x1);
                    }
                    r12 = var_40;
                    r13 = var_2C;
                    rax = dlsym(rax, "__wine_main");
                    if (rax != 0x0) {
                            (rax)(r13, r12);
                    }
                    rax = fwrite("wine: __wine_main function not found in ntdll.so\n", 0x31, 0x1, **___stderrp);
                    exit(0x1);
            }
            rax = sub_100000c00("%s/wine%s/ntdll.so", *qword_1000020a8, var_50, rcx, r8, r9, decomp_var_60);
            rax = dlopen(rax, 0x2);
            if (rax != 0x0) {
                    rax = dlsym(rax, "__wine_main");
                    if (rax != 0x0) {
                            (rax)(r13, r12);
                    }
                    rax = fwrite("wine: __wine_main function not found in ntdll.so\n", 0x31, 0x1, **___stderrp);
                    exit(0x1);
            }
            var_2C = r13;
            var_40 = r12;
            rax = getenv("WINEDLLPATH");
            if (rax == 0x0) {
                    rax = fprintf(**___stderrp, "wine: could not load ntdll.so: %s\n", dlerror());
                    exit(0x1);
            }
            rbx = rax;
            rax = strlen(rax);
            rax = malloc(rax + 0x1 + CARRY(RFLAGS(cf)));
            if (rax == 0x0) {
                    rax = fwrite("Virtual memory exhausted.\n", 0x1a, 0x1, **___stderrp);
                    exit(0x1);
            }
            r14 = rax;
            strcpy(rax, rbx);
            rax = strtok(r14, ":");
            if (rax == 0x0) {
                    free(r14);
                    rax = fprintf(**___stderrp, "wine: could not load ntdll.so: %s\n", dlerror());
                    exit(0x1);
            }
            r13 = rax;
            var_58 = r14;
            r14 = 0x0;
            var_38 = 0x0;
            r15 = 0x0;
            r12 = 0x0;
            while (true) {
                    rax = strlen(r13);
                    rcx = rax + 0x1;
                    rax = malloc(rax + 0x1 + CARRY(RFLAGS(cf)));
                    if (rax == 0x0) {
                            temp_4 = 0x1;
                            break;
                    }
                    rbx = rax;
                    strcpy(rax, r13);
                    if (r15 != r12) {
                            rax = var_38;
                            rdx = r15;
                            r15 = r15 + 0x1;
                            var_38 = rax;
                            *(rax + rdx * 0x8) = rbx;
                            rax = strtok(0x0, ":");
                            r13 = rax;
                            r14 = r14 + 0x2;
                            if (rax != 0x0) {
                                    continue;
                            }
                            free(var_58);
                            if (r15 != 0x0) {
                                    r12 = 0x8;
                                    r14 = "%s%s/ntdll.so";
                                    rbx = "%s/ntdll.so";
                                    temp_4 = 0x3;
                            }
                            else {
                                    temp_4 = 0x0;
                            }
                            break;
                    }
                    r12 = r14;
                    if (r15 == 0x0) {
                            r12 = 0x10;
                    }
                    rax = realloc(var_38, r12 * 0x8);
                    if (r12 == 0x0) {
                            rdx = r15;
                            r15 = r15 + 0x1;
                            var_38 = rax;
                            *(rax + rdx * 0x8) = rbx;
                            rax = strtok(0x0, ":");
                            r13 = rax;
                            r14 = r14 + 0x2;
                            if (rax != 0x0) {
                                    continue;
                            }
                            free(var_58);
                            if (r15 != 0x0) {
                                    r12 = 0x8;
                                    r14 = "%s%s/ntdll.so";
                                    rbx = "%s/ntdll.so";
                                    temp_4 = 0x3;
                            }
                            else {
                                    temp_4 = 0x0;
                            }
                            break;
                    }
                    if (rax != 0x0) {
                            rdx = r15;
                            r15 = r15 + 0x1;
                            var_38 = rax;
                            *(rax + rdx * 0x8) = rbx;
                            rax = strtok(0x0, ":");
                            r13 = rax;
                            r14 = r14 + 0x2;
                            if (rax != 0x0) {
                                    continue;
                            }
                            free(var_58);
                            if (r15 != 0x0) {
                                    r12 = 0x8;
                                    r14 = "%s%s/ntdll.so";
                                    rbx = "%s/ntdll.so";
                                    temp_4 = 0x3;
                            }
                            else {
                                    temp_4 = 0x0;
                            }
                            break;
                    }
                    temp_4 = 0x2;
                    break;
            }
            if (temp_4 == 0x0) {
                    rax = fprintf(**___stderrp, "wine: could not load ntdll.so: %s\n", dlerror());
                    exit(0x1);
            }
            if (temp_4 == 0x1) {
                    rax = fwrite("Virtual memory exhausted.\n", 0x1a, 0x1, **___stderrp);
                    exit(0x1);
            }
            if (temp_4 == 0x2) {
                    rax = fwrite("Virtual memory exhausted.\n", 0x1a, 0x1, **___stderrp);
                    exit(0x1);
            }
            while (true) {
                    r13 = *(var_38 + (r12 - 0x8));
                    rdx = var_50;
                    rax = sub_100000c00(r14, r13, rdx, rcx, r8, r9, decomp_var_60);
                    rax = dlopen(rax, 0x2);
                    if (rax != 0x0) {
                            temp_5 = 0x1;
                            break;
                    }
                    rax = sub_100000c00(rbx, r13, rdx, rcx, r8, r9, decomp_var_60);
                    rax = dlopen(rax, 0x2);
                    if (rax != 0x0) {
                            temp_5 = 0x1;
                            break;
                    }
                    rax = SAR(r12, 0x3);
                    r12 = r12 + 0x8;
                    if (rax < r15) {
                            continue;
                    }
                    temp_5 = 0x0;
                    break;
            }
            if (temp_5 == 0x0) {
                    rax = fprintf(**___stderrp, "wine: could not load ntdll.so: %s\n", dlerror());
                    exit(0x1);
            }
            r12 = var_40;
            r13 = var_2C;
            rax = dlsym(rax, "__wine_main");
            if (rax != 0x0) {
                    (rax)(r13, r12);
            }
            rax = fwrite("wine: __wine_main function not found in ntdll.so\n", 0x31, 0x1, **___stderrp);
            exit(0x1);
    }
    rax = malloc(0x2);
    if (rax == 0x0) {
            rax = fwrite("Virtual memory exhausted.\n", 0x1a, 0x1, **___stderrp);
            exit(0x1);
    }
    *(int16_t *)rax = 0x2e;
    *qword_1000020a0 = rax;
    var_2C = r13;
    var_40 = r12;
    rdi = "/opt/cxoffice/bin";
    rdx = "/opt/cxoffice/lib";
    while (true) {
            rdi = rdi - 0x1;
            do {
                    rcx = rdi[0x1] & 0xff;
                    rdi = rdi + 0x1;
            } while (rcx == 0x2f);
            r12 = rdx - 0x1;
            do {
                    r13 = r12[0x1] & 0xff;
                    r12 = r12 + 0x1;
            } while (r13 == 0x2f);
            if (rcx == 0x0) {
                    r15 = 0x0;
                    temp_2 = 0x1;
                    break;
            }
            rdx = r12;
            if (rcx == 0x0) {
                    rsi = *(int8_t *)rdx & 0xff;
                    if (rsi == 0x0) {
                            continue;
                    }
                    if ((rsi & 0xff) == 0x2f) {
                            continue;
                    }
                    temp_2 = 0x0;
                    break;
            }
            while (true) {
                    rsi = rcx & 0xff;
                    if (rsi == 0x2f) {
                            temp_0 = 0x1;
                            break;
                    }
                    rsi = *(int8_t *)rdx & 0xff;
                    if (rcx != rsi) {
                            temp_0 = 0x2;
                            break;
                    }
                    rdx = rdx + 0x1;
                    rcx = rdi[0x1] & 0xff;
                    rdi = rdi + 0x1;
                    if (rcx != 0x0) {
                            continue;
                    }
                    temp_0 = 0x0;
                    break;
            }
            if (temp_0 == 0x0) {
                    rsi = *(int8_t *)rdx & 0xff;
                    if (rsi == 0x0) {
                            continue;
                    }
                    if ((rsi & 0xff) == 0x2f) {
                            continue;
                    }
                    temp_2 = 0x0;
                    break;
            }
            if (temp_0 == 0x1) {
                    rsi = *(int8_t *)rdx & 0xff;
                    if (rsi == 0x0) {
                            continue;
                    }
                    if ((rsi & 0xff) == 0x2f) {
                            continue;
                    }
                    temp_2 = 0x0;
                    break;
            }
            if (rcx != 0x0) {
                    temp_2 = 0x0;
                    break;
            }
            if (rsi == 0x0) {
                    continue;
            }
            if ((rsi & 0xff) == 0x2f) {
                    continue;
            }
            temp_2 = 0x0;
            break;
    }
    if (temp_2 == 0x0) {
            r15 = 0x0;
            temp_3 = 0x4;
            while (true) {
                    if (temp_3 == 0x4) {
                            r15 = r15 + 0x1;
                            if (rcx != 0x2f) {
                                    while (true) {
                                            rcx = rcx & 0xff;
                                            if (rcx == 0x0) {
                                                    temp_1 = 0x0;
                                                    break;
                                            }
                                            rcx = rdi[0x1] & 0xff;
                                            rdi = rdi + 0x1;
                                            if (rcx != 0x2f) {
                                                    continue;
                                            }
                                            temp_1 = 0x1;
                                            break;
                                    }
                                    temp_3 = 0x8;
                                    continue;
                            }
                            rcx = *(int8_t *)rdi & 0xff;
                            if (rcx == 0x2f) {
                                    rdi = rdi + 0x1;
                                    temp_3 = 0x8;
                                    continue;
                            }
                            if (rcx != 0x0) {
                                    temp_3 = 0x4;
                                    continue;
                            }
                            break;
                    }
                    rcx = *(int8_t *)rdi & 0xff;
                    if (rcx == 0x2f) {
                            rdi = rdi + 0x1;
                            temp_3 = 0x8;
                            continue;
                    }
                    if (rcx == 0x0) {
                            break;
                    }
                    temp_3 = 0x4;
            }
    }
    var_38 = rax;
    rbx = strlen(rax);
    rax = strlen(r12);
    rax = malloc(r15 + r15 * 0x2 + rbx + rax + 0x2 + CARRY(RFLAGS(cf)));
    if (rax == 0x0) {
            rax = fwrite("Virtual memory exhausted.\n", 0x1a, 0x1, **___stderrp);
            exit(0x1);
    }
    r14 = rax;
    strcpy(rax, var_38);
    if (r15 != 0x0) {
            do {
                    *(int32_t *)(r14 + strlen(r14)) = 0x2e2e2f;
                    r15 = r15 - 0x1;
            } while (r15 != 0x0);
    }
    if (r13 != 0x0) {
            *(int16_t *)(r14 + strlen(r14)) = 0x2f;
            strcat(r14, r12);
    }
    r12 = var_40;
    r13 = var_2C;
    *qword_1000020a8 = r14;
    var_50 = sub_100000c00("/%s-%s", "x86_64", "unix", rcx, r8, r9, decomp_var_60);
    if (*qword_1000020a0 != 0x0) {
            rax = strlen(*qword_1000020a0);
            if (rax < 0xb) {
                    rax = sub_100000c00("%s/wine%s/ntdll.so", *qword_1000020a8, var_50, rcx, r8, r9, decomp_var_60);
                    rax = dlopen(rax, 0x2);
                    if (rax != 0x0) {
                            rax = dlsym(rax, "__wine_main");
                            if (rax != 0x0) {
                                    (rax)(r13, r12);
                            }
                            rax = fwrite("wine: __wine_main function not found in ntdll.so\n", 0x31, 0x1, **___stderrp);
                            exit(0x1);
                    }
                    var_2C = r13;
                    var_40 = r12;
                    rax = getenv("WINEDLLPATH");
                    if (rax == 0x0) {
                            rax = fprintf(**___stderrp, "wine: could not load ntdll.so: %s\n", dlerror());
                            exit(0x1);
                    }
                    rbx = rax;
                    rax = strlen(rax);
                    rax = malloc(rax + 0x1 + CARRY(RFLAGS(cf)));
                    if (rax == 0x0) {
                            rax = fwrite("Virtual memory exhausted.\n", 0x1a, 0x1, **___stderrp);
                            exit(0x1);
                    }
                    r14 = rax;
                    strcpy(rax, rbx);
                    rax = strtok(r14, ":");
                    if (rax == 0x0) {
                            free(r14);
                            rax = fprintf(**___stderrp, "wine: could not load ntdll.so: %s\n", dlerror());
                            exit(0x1);
                    }
                    r13 = rax;
                    var_58 = r14;
                    r14 = 0x0;
                    var_38 = 0x0;
                    r15 = 0x0;
                    r12 = 0x0;
                    while (true) {
                            rax = strlen(r13);
                            rcx = rax + 0x1;
                            rax = malloc(rax + 0x1 + CARRY(RFLAGS(cf)));
                            if (rax == 0x0) {
                                    temp_4 = 0x1;
                                    break;
                            }
                            rbx = rax;
                            strcpy(rax, r13);
                            if (r15 != r12) {
                                    rax = var_38;
                                    rdx = r15;
                                    r15 = r15 + 0x1;
                                    var_38 = rax;
                                    *(rax + rdx * 0x8) = rbx;
                                    rax = strtok(0x0, ":");
                                    r13 = rax;
                                    r14 = r14 + 0x2;
                                    if (rax != 0x0) {
                                            continue;
                                    }
                                    free(var_58);
                                    if (r15 != 0x0) {
                                            r12 = 0x8;
                                            r14 = "%s%s/ntdll.so";
                                            rbx = "%s/ntdll.so";
                                            temp_4 = 0x3;
                                    }
                                    else {
                                            temp_4 = 0x0;
                                    }
                                    break;
                            }
                            r12 = r14;
                            if (r15 == 0x0) {
                                    r12 = 0x10;
                            }
                            rax = realloc(var_38, r12 * 0x8);
                            if (r12 == 0x0) {
                                    rdx = r15;
                                    r15 = r15 + 0x1;
                                    var_38 = rax;
                                    *(rax + rdx * 0x8) = rbx;
                                    rax = strtok(0x0, ":");
                                    r13 = rax;
                                    r14 = r14 + 0x2;
                                    if (rax != 0x0) {
                                            continue;
                                    }
                                    free(var_58);
                                    if (r15 != 0x0) {
                                            r12 = 0x8;
                                            r14 = "%s%s/ntdll.so";
                                            rbx = "%s/ntdll.so";
                                            temp_4 = 0x3;
                                    }
                                    else {
                                            temp_4 = 0x0;
                                    }
                                    break;
                            }
                            if (rax != 0x0) {
                                    rdx = r15;
                                    r15 = r15 + 0x1;
                                    var_38 = rax;
                                    *(rax + rdx * 0x8) = rbx;
                                    rax = strtok(0x0, ":");
                                    r13 = rax;
                                    r14 = r14 + 0x2;
                                    if (rax != 0x0) {
                                            continue;
                                    }
                                    free(var_58);
                                    if (r15 != 0x0) {
                                            r12 = 0x8;
                                            r14 = "%s%s/ntdll.so";
                                            rbx = "%s/ntdll.so";
                                            temp_4 = 0x3;
                                    }
                                    else {
                                            temp_4 = 0x0;
                                    }
                                    break;
                            }
                            temp_4 = 0x2;
                            break;
                    }
                    if (temp_4 == 0x0) {
                            rax = fprintf(**___stderrp, "wine: could not load ntdll.so: %s\n", dlerror());
                            exit(0x1);
                    }
                    if (temp_4 == 0x1) {
                            rax = fwrite("Virtual memory exhausted.\n", 0x1a, 0x1, **___stderrp);
                            exit(0x1);
                    }
                    if (temp_4 == 0x2) {
                            rax = fwrite("Virtual memory exhausted.\n", 0x1a, 0x1, **___stderrp);
                            exit(0x1);
                    }
                    while (true) {
                            r13 = *(var_38 + (r12 - 0x8));
                            rdx = var_50;
                            rax = sub_100000c00(r14, r13, rdx, rcx, r8, r9, decomp_var_60);
                            rax = dlopen(rax, 0x2);
                            if (rax != 0x0) {
                                    temp_5 = 0x1;
                                    break;
                            }
                            rax = sub_100000c00(rbx, r13, rdx, rcx, r8, r9, decomp_var_60);
                            rax = dlopen(rax, 0x2);
                            if (rax != 0x0) {
                                    temp_5 = 0x1;
                                    break;
                            }
                            rax = SAR(r12, 0x3);
                            r12 = r12 + 0x8;
                            if (rax < r15) {
                                    continue;
                            }
                            temp_5 = 0x0;
                            break;
                    }
                    if (temp_5 == 0x0) {
                            rax = fprintf(**___stderrp, "wine: could not load ntdll.so: %s\n", dlerror());
                            exit(0x1);
                    }
                    r12 = var_40;
                    r13 = var_2C;
                    rax = dlsym(rax, "__wine_main");
                    if (rax != 0x0) {
                            (rax)(r13, r12);
                    }
                    rax = fwrite("wine: __wine_main function not found in ntdll.so\n", 0x31, 0x1, **___stderrp);
                    exit(0x1);
            }
            rax = sign_extend_32(rax);
            if (strcmp(*qword_1000020a0 + (rax - 0xb), "/tools/wine") != 0x0) {
                    rax = sub_100000c00("%s/wine%s/ntdll.so", *qword_1000020a8, var_50, rcx, r8, r9, decomp_var_60);
                    rax = dlopen(rax, 0x2);
                    if (rax != 0x0) {
                            rax = dlsym(rax, "__wine_main");
                            if (rax != 0x0) {
                                    (rax)(r13, r12);
                            }
                            rax = fwrite("wine: __wine_main function not found in ntdll.so\n", 0x31, 0x1, **___stderrp);
                            exit(0x1);
                    }
                    var_2C = r13;
                    var_40 = r12;
                    rax = getenv("WINEDLLPATH");
                    if (rax == 0x0) {
                            rax = fprintf(**___stderrp, "wine: could not load ntdll.so: %s\n", dlerror());
                            exit(0x1);
                    }
                    rbx = rax;
                    rax = strlen(rax);
                    rax = malloc(rax + 0x1 + CARRY(RFLAGS(cf)));
                    if (rax == 0x0) {
                            rax = fwrite("Virtual memory exhausted.\n", 0x1a, 0x1, **___stderrp);
                            exit(0x1);
                    }
                    r14 = rax;
                    strcpy(rax, rbx);
                    rax = strtok(r14, ":");
                    if (rax == 0x0) {
                            free(r14);
                            rax = fprintf(**___stderrp, "wine: could not load ntdll.so: %s\n", dlerror());
                            exit(0x1);
                    }
                    r13 = rax;
                    var_58 = r14;
                    r14 = 0x0;
                    var_38 = 0x0;
                    r15 = 0x0;
                    r12 = 0x0;
                    while (true) {
                            rax = strlen(r13);
                            rcx = rax + 0x1;
                            rax = malloc(rax + 0x1 + CARRY(RFLAGS(cf)));
                            if (rax == 0x0) {
                                    temp_4 = 0x1;
                                    break;
                            }
                            rbx = rax;
                            strcpy(rax, r13);
                            if (r15 != r12) {
                                    rax = var_38;
                                    rdx = r15;
                                    r15 = r15 + 0x1;
                                    var_38 = rax;
                                    *(rax + rdx * 0x8) = rbx;
                                    rax = strtok(0x0, ":");
                                    r13 = rax;
                                    r14 = r14 + 0x2;
                                    if (rax != 0x0) {
                                            continue;
                                    }
                                    free(var_58);
                                    if (r15 != 0x0) {
                                            r12 = 0x8;
                                            r14 = "%s%s/ntdll.so";
                                            rbx = "%s/ntdll.so";
                                            temp_4 = 0x3;
                                    }
                                    else {
                                            temp_4 = 0x0;
                                    }
                                    break;
                            }
                            r12 = r14;
                            if (r15 == 0x0) {
                                    r12 = 0x10;
                            }
                            rax = realloc(var_38, r12 * 0x8);
                            if (r12 == 0x0) {
                                    rdx = r15;
                                    r15 = r15 + 0x1;
                                    var_38 = rax;
                                    *(rax + rdx * 0x8) = rbx;
                                    rax = strtok(0x0, ":");
                                    r13 = rax;
                                    r14 = r14 + 0x2;
                                    if (rax != 0x0) {
                                            continue;
                                    }
                                    free(var_58);
                                    if (r15 != 0x0) {
                                            r12 = 0x8;
                                            r14 = "%s%s/ntdll.so";
                                            rbx = "%s/ntdll.so";
                                            temp_4 = 0x3;
                                    }
                                    else {
                                            temp_4 = 0x0;
                                    }
                                    break;
                            }
                            if (rax != 0x0) {
                                    rdx = r15;
                                    r15 = r15 + 0x1;
                                    var_38 = rax;
                                    *(rax + rdx * 0x8) = rbx;
                                    rax = strtok(0x0, ":");
                                    r13 = rax;
                                    r14 = r14 + 0x2;
                                    if (rax != 0x0) {
                                            continue;
                                    }
                                    free(var_58);
                                    if (r15 != 0x0) {
                                            r12 = 0x8;
                                            r14 = "%s%s/ntdll.so";
                                            rbx = "%s/ntdll.so";
                                            temp_4 = 0x3;
                                    }
                                    else {
                                            temp_4 = 0x0;
                                    }
                                    break;
                            }
                            temp_4 = 0x2;
                            break;
                    }
                    if (temp_4 == 0x0) {
                            rax = fprintf(**___stderrp, "wine: could not load ntdll.so: %s\n", dlerror());
                            exit(0x1);
                    }
                    if (temp_4 == 0x1) {
                            rax = fwrite("Virtual memory exhausted.\n", 0x1a, 0x1, **___stderrp);
                            exit(0x1);
                    }
                    if (temp_4 == 0x2) {
                            rax = fwrite("Virtual memory exhausted.\n", 0x1a, 0x1, **___stderrp);
                            exit(0x1);
                    }
                    while (true) {
                            r13 = *(var_38 + (r12 - 0x8));
                            rdx = var_50;
                            rax = sub_100000c00(r14, r13, rdx, rcx, r8, r9, decomp_var_60);
                            rax = dlopen(rax, 0x2);
                            if (rax != 0x0) {
                                    temp_5 = 0x1;
                                    break;
                            }
                            rax = sub_100000c00(rbx, r13, rdx, rcx, r8, r9, decomp_var_60);
                            rax = dlopen(rax, 0x2);
                            if (rax != 0x0) {
                                    temp_5 = 0x1;
                                    break;
                            }
                            rax = SAR(r12, 0x3);
                            r12 = r12 + 0x8;
                            if (rax < r15) {
                                    continue;
                            }
                            temp_5 = 0x0;
                            break;
                    }
                    if (temp_5 == 0x0) {
                            rax = fprintf(**___stderrp, "wine: could not load ntdll.so: %s\n", dlerror());
                            exit(0x1);
                    }
                    r12 = var_40;
                    r13 = var_2C;
                    rax = dlsym(rax, "__wine_main");
                    if (rax != 0x0) {
                            (rax)(r13, r12);
                    }
                    rax = fwrite("wine: __wine_main function not found in ntdll.so\n", 0x31, 0x1, **___stderrp);
                    exit(0x1);
            }
            rax = sub_100000c00("%s/../../dlls/ntdll/ntdll.so", *qword_1000020a0, "unix", rcx, r8, r9, decomp_var_60);
            rax = dlopen(rax, 0x2);
            if (rax != 0x0) {
                    rax = dlsym(rax, "__wine_main");
                    if (rax != 0x0) {
                            (rax)(r13, r12);
                    }
                    rax = fwrite("wine: __wine_main function not found in ntdll.so\n", 0x31, 0x1, **___stderrp);
                    exit(0x1);
            }
            rax = sub_100000c00("%s/wine%s/ntdll.so", *qword_1000020a8, var_50, rcx, r8, r9, decomp_var_60);
            rax = dlopen(rax, 0x2);
            if (rax != 0x0) {
                    rax = dlsym(rax, "__wine_main");
                    if (rax != 0x0) {
                            (rax)(r13, r12);
                    }
                    rax = fwrite("wine: __wine_main function not found in ntdll.so\n", 0x31, 0x1, **___stderrp);
                    exit(0x1);
            }
            var_2C = r13;
            var_40 = r12;
            rax = getenv("WINEDLLPATH");
            if (rax == 0x0) {
                    rax = fprintf(**___stderrp, "wine: could not load ntdll.so: %s\n", dlerror());
                    exit(0x1);
            }
            rbx = rax;
            rax = strlen(rax);
            rax = malloc(rax + 0x1 + CARRY(RFLAGS(cf)));
            if (rax == 0x0) {
                    rax = fwrite("Virtual memory exhausted.\n", 0x1a, 0x1, **___stderrp);
                    exit(0x1);
            }
            r14 = rax;
            strcpy(rax, rbx);
            rax = strtok(r14, ":");
            if (rax == 0x0) {
                    free(r14);
                    rax = fprintf(**___stderrp, "wine: could not load ntdll.so: %s\n", dlerror());
                    exit(0x1);
            }
            r13 = rax;
            var_58 = r14;
            r14 = 0x0;
            var_38 = 0x0;
            r15 = 0x0;
            r12 = 0x0;
            while (true) {
                    rax = strlen(r13);
                    rcx = rax + 0x1;
                    rax = malloc(rax + 0x1 + CARRY(RFLAGS(cf)));
                    if (rax == 0x0) {
                            temp_4 = 0x1;
                            break;
                    }
                    rbx = rax;
                    strcpy(rax, r13);
                    if (r15 != r12) {
                            rax = var_38;
                            rdx = r15;
                            r15 = r15 + 0x1;
                            var_38 = rax;
                            *(rax + rdx * 0x8) = rbx;
                            rax = strtok(0x0, ":");
                            r13 = rax;
                            r14 = r14 + 0x2;
                            if (rax != 0x0) {
                                    continue;
                            }
                            free(var_58);
                            if (r15 != 0x0) {
                                    r12 = 0x8;
                                    r14 = "%s%s/ntdll.so";
                                    rbx = "%s/ntdll.so";
                                    temp_4 = 0x3;
                            }
                            else {
                                    temp_4 = 0x0;
                            }
                            break;
                    }
                    r12 = r14;
                    if (r15 == 0x0) {
                            r12 = 0x10;
                    }
                    rax = realloc(var_38, r12 * 0x8);
                    if (r12 == 0x0) {
                            rdx = r15;
                            r15 = r15 + 0x1;
                            var_38 = rax;
                            *(rax + rdx * 0x8) = rbx;
                            rax = strtok(0x0, ":");
                            r13 = rax;
                            r14 = r14 + 0x2;
                            if (rax != 0x0) {
                                    continue;
                            }
                            free(var_58);
                            if (r15 != 0x0) {
                                    r12 = 0x8;
                                    r14 = "%s%s/ntdll.so";
                                    rbx = "%s/ntdll.so";
                                    temp_4 = 0x3;
                            }
                            else {
                                    temp_4 = 0x0;
                            }
                            break;
                    }
                    if (rax != 0x0) {
                            rdx = r15;
                            r15 = r15 + 0x1;
                            var_38 = rax;
                            *(rax + rdx * 0x8) = rbx;
                            rax = strtok(0x0, ":");
                            r13 = rax;
                            r14 = r14 + 0x2;
                            if (rax != 0x0) {
                                    continue;
                            }
                            free(var_58);
                            if (r15 != 0x0) {
                                    r12 = 0x8;
                                    r14 = "%s%s/ntdll.so";
                                    rbx = "%s/ntdll.so";
                                    temp_4 = 0x3;
                            }
                            else {
                                    temp_4 = 0x0;
                            }
                            break;
                    }
                    temp_4 = 0x2;
                    break;
            }
            if (temp_4 == 0x0) {
                    rax = fprintf(**___stderrp, "wine: could not load ntdll.so: %s\n", dlerror());
                    exit(0x1);
            }
            if (temp_4 == 0x1) {
                    rax = fwrite("Virtual memory exhausted.\n", 0x1a, 0x1, **___stderrp);
                    exit(0x1);
            }
            if (temp_4 == 0x2) {
                    rax = fwrite("Virtual memory exhausted.\n", 0x1a, 0x1, **___stderrp);
                    exit(0x1);
            }
            while (true) {
                    r13 = *(var_38 + (r12 - 0x8));
                    rdx = var_50;
                    rax = sub_100000c00(r14, r13, rdx, rcx, r8, r9, decomp_var_60);
                    rax = dlopen(rax, 0x2);
                    if (rax != 0x0) {
                            temp_5 = 0x1;
                            break;
                    }
                    rax = sub_100000c00(rbx, r13, rdx, rcx, r8, r9, decomp_var_60);
                    rax = dlopen(rax, 0x2);
                    if (rax != 0x0) {
                            temp_5 = 0x1;
                            break;
                    }
                    rax = SAR(r12, 0x3);
                    r12 = r12 + 0x8;
                    if (rax < r15) {
                            continue;
                    }
                    temp_5 = 0x0;
                    break;
            }
            if (temp_5 == 0x0) {
                    rax = fprintf(**___stderrp, "wine: could not load ntdll.so: %s\n", dlerror());
                    exit(0x1);
            }
            r12 = var_40;
            r13 = var_2C;
            rax = dlsym(rax, "__wine_main");
            if (rax != 0x0) {
                    (rax)(r13, r12);
            }
            rax = fwrite("wine: __wine_main function not found in ntdll.so\n", 0x31, 0x1, **___stderrp);
            exit(0x1);
    }
    rax = sub_100000c00("%s/wine%s/ntdll.so", *qword_1000020a8, var_50, rcx, r8, r9, decomp_var_60);
    rax = dlopen(rax, 0x2);
    if (rax != 0x0) {
            rax = dlsym(rax, "__wine_main");
            if (rax != 0x0) {
                    (rax)(r13, r12);
            }
            rax = fwrite("wine: __wine_main function not found in ntdll.so\n", 0x31, 0x1, **___stderrp);
            exit(0x1);
    }
    var_2C = r13;
    var_40 = r12;
    rax = getenv("WINEDLLPATH");
    if (rax == 0x0) {
            rax = fprintf(**___stderrp, "wine: could not load ntdll.so: %s\n", dlerror());
            exit(0x1);
    }
    rbx = rax;
    rax = strlen(rax);
    rax = malloc(rax + 0x1 + CARRY(RFLAGS(cf)));
    if (rax == 0x0) {
            rax = fwrite("Virtual memory exhausted.\n", 0x1a, 0x1, **___stderrp);
            exit(0x1);
    }
    r14 = rax;
    strcpy(rax, rbx);
    rax = strtok(r14, ":");
    if (rax == 0x0) {
            free(r14);
            rax = fprintf(**___stderrp, "wine: could not load ntdll.so: %s\n", dlerror());
            exit(0x1);
    }
    r13 = rax;
    var_58 = r14;
    r14 = 0x0;
    var_38 = 0x0;
    r15 = 0x0;
    r12 = 0x0;
    while (true) {
            rax = strlen(r13);
            rcx = rax + 0x1;
            rax = malloc(rax + 0x1 + CARRY(RFLAGS(cf)));
            if (rax == 0x0) {
                    temp_4 = 0x1;
                    break;
            }
            rbx = rax;
            strcpy(rax, r13);
            if (r15 != r12) {
                    rax = var_38;
                    rdx = r15;
                    r15 = r15 + 0x1;
                    var_38 = rax;
                    *(rax + rdx * 0x8) = rbx;
                    rax = strtok(0x0, ":");
                    r13 = rax;
                    r14 = r14 + 0x2;
                    if (rax != 0x0) {
                            continue;
                    }
                    free(var_58);
                    if (r15 != 0x0) {
                            r12 = 0x8;
                            r14 = "%s%s/ntdll.so";
                            rbx = "%s/ntdll.so";
                            temp_4 = 0x3;
                    }
                    else {
                            temp_4 = 0x0;
                    }
                    break;
            }
            r12 = r14;
            if (r15 == 0x0) {
                    r12 = 0x10;
            }
            rax = realloc(var_38, r12 * 0x8);
            if (r12 == 0x0) {
                    rdx = r15;
                    r15 = r15 + 0x1;
                    var_38 = rax;
                    *(rax + rdx * 0x8) = rbx;
                    rax = strtok(0x0, ":");
                    r13 = rax;
                    r14 = r14 + 0x2;
                    if (rax != 0x0) {
                            continue;
                    }
                    free(var_58);
                    if (r15 != 0x0) {
                            r12 = 0x8;
                            r14 = "%s%s/ntdll.so";
                            rbx = "%s/ntdll.so";
                            temp_4 = 0x3;
                    }
                    else {
                            temp_4 = 0x0;
                    }
                    break;
            }
            if (rax != 0x0) {
                    rdx = r15;
                    r15 = r15 + 0x1;
                    var_38 = rax;
                    *(rax + rdx * 0x8) = rbx;
                    rax = strtok(0x0, ":");
                    r13 = rax;
                    r14 = r14 + 0x2;
                    if (rax != 0x0) {
                            continue;
                    }
                    free(var_58);
                    if (r15 != 0x0) {
                            r12 = 0x8;
                            r14 = "%s%s/ntdll.so";
                            rbx = "%s/ntdll.so";
                            temp_4 = 0x3;
                    }
                    else {
                            temp_4 = 0x0;
                    }
                    break;
            }
            temp_4 = 0x2;
            break;
    }
    if (temp_4 == 0x0) {
            rax = fprintf(**___stderrp, "wine: could not load ntdll.so: %s\n", dlerror());
            exit(0x1);
    }
    if (temp_4 == 0x1) {
            rax = fwrite("Virtual memory exhausted.\n", 0x1a, 0x1, **___stderrp);
            exit(0x1);
    }
    if (temp_4 == 0x2) {
            rax = fwrite("Virtual memory exhausted.\n", 0x1a, 0x1, **___stderrp);
            exit(0x1);
    }
    while (true) {
            r13 = *(var_38 + (r12 - 0x8));
            rdx = var_50;
            rax = sub_100000c00(r14, r13, rdx, rcx, r8, r9, decomp_var_60);
            rax = dlopen(rax, 0x2);
            if (rax != 0x0) {
                    temp_5 = 0x1;
                    break;
            }
            rax = sub_100000c00(rbx, r13, rdx, rcx, r8, r9, decomp_var_60);
            rax = dlopen(rax, 0x2);
            if (rax != 0x0) {
                    temp_5 = 0x1;
                    break;
            }
            rax = SAR(r12, 0x3);
            r12 = r12 + 0x8;
            if (rax < r15) {
                    continue;
            }
            temp_5 = 0x0;
            break;
    }
    if (temp_5 == 0x0) {
            rax = fprintf(**___stderrp, "wine: could not load ntdll.so: %s\n", dlerror());
            exit(0x1);
    }
    r12 = var_40;
    r13 = var_2C;
    rax = dlsym(rax, "__wine_main");
    if (rax != 0x0) {
            (rax)(r13, r12);
    }
    rax = fwrite("wine: __wine_main function not found in ntdll.so\n", 0x31, 0x1, **___stderrp);
    exit(0x1);
    return rax;
