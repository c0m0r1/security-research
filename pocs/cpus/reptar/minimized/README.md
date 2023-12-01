# Minimized Reptar Examples

This directory provides a set of examples to reproduce and study the Reptar vulnerability.

You can build them all simply by running `make`. Building the code requires `nasm`, `binutils` (for `ld`) and `make`. On an ubuntu system you can install these with `apt install -y nasm make binutils`.

## Quick Summary

- **reptar.align.elf.asm**: This is a more reliable reproducer that triggers an error on the first iteration. The `clflush` and the reptar instruction need to be on different 16 byte windows. This could be related to the instruction decoder working on 16 byte instructions at a time.
- **reptar.boot.bin.asm**: Same as align, but instead intended to be ran from a VM using KVM. `qemu-system-x86_64 --enable-kvm -fda reptar.boot.bin`.
- **reptar.xlat.elf.asm**: This is similar to `reptar.align.elf.asm` but generates tracing information on the syscalls it executes, so that when the program enters at a different register location, it is possible to observe the consequences. Pause will freeze the process, exit will pass `AL` as the exit code and yield will simply leave the latest `RIP` on `RCX`.
- **reptar.loopless.elf.asm**: This is an easier to modify reproducer that will also trigger the bug somewhat reliably but also allows to modify the instructions executed before and after. Note the registers that the program uses at the top.
- **reptar.loop.elf.asm**: This is a more documented reproducer that explains what happens when the bug triggers and which instructions execute and which don't. Running the program on GDB should allow for quick debugging.
- **reptar.vdso.bin.asm**: This is an experiment where we map ourselves just before the VDSO (you must disable ASLR first and adjust the addresses) and then make the "wrong RIP" point to the VDSO address of the time() function. As a result, the current time is stored in the address pointed to by RAX, which is then clflushed so it triggers a segfault to the current time. If we had corrupted the uop$ then we would instead expect a crash, so it appears that a long jump to the VDSO doesn't corrupt the uop$. To test try: `taskset -c 7 gdb ./reptar.vdso.bin  -ex r -ex 'python import datetime;print(datetime.datetime.utcfromtimestamp(gdb.parse_and_eval("*$rdi")))' -ex q` - if successful you should see the current date/time.
- **reptar.mce.elf.asm**: Trigger this with `./log_mce.sh` and adjust the cpu 15/7 so they are siblings. This code will trigger an MCE on some affected CPUs and log the details. Look at `mce.txt` for the expected MCE errors. If no MCE is visible, define `MCE_INSTRUCTION='rep movsb'` as that works instead on some CPUs.
