"""Run a process on a separate hidden Win32 desktop.

A window created on a Win32 desktop other than the interactive one can never be
shown on, activate on, or take focus from the user's desktop: the two are entirely
separate input surfaces as far as Windows is concerned. The GPU still renders to a
window on the hidden desktop exactly as it would on the visible one, which is why
`tools/smoke.py --shots` can run Godot here and still get real screenshots without
ever flashing a window, alt-tabbing the owner out of a fullscreen game, or stealing
their cursor.
"""
from __future__ import annotations

import os
import pathlib
import subprocess
import sys
import tempfile
import time


def run_hidden(args: list[str], cwd: pathlib.Path, timeout: float) -> tuple[int, str]:
    """Launch args on a new hidden desktop, wait up to timeout seconds, and return
    (exit code, combined stdout+stderr). Raises subprocess.TimeoutExpired on timeout
    and OSError (with the Win32 error code in the message) if desktop or process
    creation fails.
    """
    import ctypes
    import ctypes.wintypes as wt
    import msvcrt

    user32 = ctypes.WinDLL("user32", use_last_error=True)
    kernel32 = ctypes.WinDLL("kernel32", use_last_error=True)

    GENERIC_ALL = 0x10000000
    HANDLE_FLAG_INHERIT = 1
    STARTF_USESTDHANDLES = 0x100
    CREATE_NO_WINDOW = 0x08000000
    WAIT_TIMEOUT = 0x102

    user32.CreateDesktopW.restype = wt.HANDLE
    user32.CreateDesktopW.argtypes = [
        wt.LPCWSTR, wt.LPCWSTR, ctypes.c_void_p, wt.DWORD, wt.DWORD, ctypes.c_void_p,
    ]

    class STARTUPINFOW(ctypes.Structure):
        _fields_ = [
            ("cb", wt.DWORD), ("lpReserved", wt.LPWSTR), ("lpDesktop", wt.LPWSTR),
            ("lpTitle", wt.LPWSTR), ("dwX", wt.DWORD), ("dwY", wt.DWORD),
            ("dwXSize", wt.DWORD), ("dwYSize", wt.DWORD), ("dwXCountChars", wt.DWORD),
            ("dwYCountChars", wt.DWORD), ("dwFillAttribute", wt.DWORD), ("dwFlags", wt.DWORD),
            ("wShowWindow", wt.WORD), ("cbReserved2", wt.WORD), ("lpReserved2", ctypes.c_void_p),
            ("hStdInput", wt.HANDLE), ("hStdOutput", wt.HANDLE), ("hStdError", wt.HANDLE),
        ]

    class PROCESS_INFORMATION(ctypes.Structure):
        _fields_ = [
            ("hProcess", wt.HANDLE), ("hThread", wt.HANDLE),
            ("dwProcessId", wt.DWORD), ("dwThreadId", wt.DWORD),
        ]

    kernel32.CreateProcessW.argtypes = [
        wt.LPCWSTR, wt.LPWSTR, ctypes.c_void_p, ctypes.c_void_p, wt.BOOL,
        wt.DWORD, ctypes.c_void_p, wt.LPCWSTR,
        ctypes.POINTER(STARTUPINFOW), ctypes.POINTER(PROCESS_INFORMATION),
    ]

    name = f"van-gunner-shots-{os.getpid()}-{time.monotonic_ns()}"
    hdesk = user32.CreateDesktopW(name, None, None, 0, GENERIC_ALL, None)
    if not hdesk:
        raise OSError(f"CreateDesktopW failed: {ctypes.get_last_error()}")

    outf = tempfile.TemporaryFile()
    nul = open("NUL", "rb")
    pi = PROCESS_INFORMATION()
    try:
        hout = wt.HANDLE(msvcrt.get_osfhandle(outf.fileno()))
        hin = wt.HANDLE(msvcrt.get_osfhandle(nul.fileno()))
        kernel32.SetHandleInformation(hout, HANDLE_FLAG_INHERIT, HANDLE_FLAG_INHERIT)
        kernel32.SetHandleInformation(hin, HANDLE_FLAG_INHERIT, HANDLE_FLAG_INHERIT)

        si = STARTUPINFOW()
        si.cb = ctypes.sizeof(si)
        si.lpDesktop = name
        si.dwFlags = STARTF_USESTDHANDLES
        si.hStdInput = hin
        si.hStdOutput = hout
        si.hStdError = hout

        cmd = subprocess.list2cmdline(args)
        buf = ctypes.create_unicode_buffer(cmd)
        ok = kernel32.CreateProcessW(
            None, buf, None, None, True, CREATE_NO_WINDOW, None, str(cwd),
            ctypes.byref(si), ctypes.byref(pi),
        )
        if not ok:
            raise OSError(f"CreateProcessW failed: {ctypes.get_last_error()}")

        result = kernel32.WaitForSingleObject(pi.hProcess, int(timeout * 1000))
        if result == WAIT_TIMEOUT:
            kernel32.TerminateProcess(pi.hProcess, 1)
            kernel32.WaitForSingleObject(pi.hProcess, 10_000)
            raise subprocess.TimeoutExpired(args, timeout)

        code = wt.DWORD()
        kernel32.GetExitCodeProcess(pi.hProcess, ctypes.byref(code))
        exit_code = code.value
    finally:
        if pi.hProcess:
            kernel32.CloseHandle(pi.hProcess)
        if pi.hThread:
            kernel32.CloseHandle(pi.hThread)
        nul.close()
        user32.CloseDesktop(hdesk)

    outf.seek(0)
    output = outf.read().decode("utf-8", errors="replace")
    outf.close()
    return exit_code, output
