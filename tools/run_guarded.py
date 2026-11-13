"""Run one test with a timeout and Windows memory cutoffs; stop only its process tree."""
import argparse
import ctypes
from dataclasses import dataclass
import os
from pathlib import Path
import signal
import subprocess
import sys
import time

MIB = 1024 * 1024
MEMORY_EXIT = 125


@dataclass(frozen=True)
class Memory:
    private: int
    free_commit: int
    free_ram: int


def memory_sample(pid):
    if os.name != "nt":
        return None
    from ctypes import wintypes

    class Status(ctypes.Structure):
        _fields_ = [("length", wintypes.DWORD), ("load", wintypes.DWORD)] + [
            (name, ctypes.c_ulonglong) for name in
            ("total_ram", "free_ram", "total_commit", "free_commit", "total_virtual", "free_virtual", "extended")]

    class Counters(ctypes.Structure):
        _fields_ = [("cb", wintypes.DWORD), ("faults", wintypes.DWORD)] + [
            (name, ctypes.c_size_t) for name in
            ("peak_working", "working", "peak_paged", "paged", "peak_nonpaged", "nonpaged", "pagefile", "peak_pagefile", "private")]

    kernel = ctypes.WinDLL("kernel32", use_last_error=True)
    kernel.GlobalMemoryStatusEx.argtypes = [ctypes.POINTER(Status)]
    kernel.GlobalMemoryStatusEx.restype = wintypes.BOOL
    status = Status()
    status.length = ctypes.sizeof(status)
    if not kernel.GlobalMemoryStatusEx(ctypes.byref(status)):
        raise ctypes.WinError(ctypes.get_last_error())
    private = 0
    if pid is not None:
        kernel.OpenProcess.argtypes = [wintypes.DWORD, wintypes.BOOL, wintypes.DWORD]
        kernel.OpenProcess.restype = wintypes.HANDLE
        kernel.CloseHandle.argtypes = [wintypes.HANDLE]
        handle = kernel.OpenProcess(0x0400 | 0x0010, False, pid)
        if not handle:
            raise ctypes.WinError(ctypes.get_last_error())
        try:
            api = ctypes.WinDLL("psapi", use_last_error=True)
            api.GetProcessMemoryInfo.argtypes = [wintypes.HANDLE, ctypes.POINTER(Counters), wintypes.DWORD]
            api.GetProcessMemoryInfo.restype = wintypes.BOOL
            counters = Counters()
            counters.cb = ctypes.sizeof(counters)
            if not api.GetProcessMemoryInfo(handle, ctypes.byref(counters), counters.cb):
                raise ctypes.WinError(ctypes.get_last_error())
            private = counters.private
        finally:
            kernel.CloseHandle(handle)
    return Memory(private, status.free_commit, status.free_ram)


def _stop(process):
    if process.poll() is not None:
        return
    if os.name == "nt":
        subprocess.run(["taskkill.exe", "/PID", str(process.pid), "/T", "/F"],
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=False)
    else:
        try:
            os.killpg(process.pid, signal.SIGTERM)
        except ProcessLookupError:
            return
    try:
        process.wait(timeout=3)
    except subprocess.TimeoutExpired:
        if os.name != "nt":
            os.killpg(process.pid, signal.SIGKILL)
        process.kill()
        process.wait(timeout=3)


def run(command, timeout=900, max_private=4096 * MIB, min_commit=8192 * MIB,
        min_ram=4096 * MIB, sample=None, log=None, interval=0.25, stdout=None, stderr=None):
    sample = sample or memory_sample
    log = log or sys.stderr

    def reason(memory):
        if memory is None:
            return ""
        if memory.private > max_private:
            return f"process private memory {memory.private // MIB} MiB exceeds {max_private // MIB} MiB"
        if memory.free_commit < min_commit:
            return f"free system commit {memory.free_commit // MIB} MiB below {min_commit // MIB} MiB"
        if memory.free_ram < min_ram:
            return f"free RAM {memory.free_ram // MIB} MiB below {min_ram // MIB} MiB"
        return ""

    initial = sample(None)
    blocked = reason(initial)
    if blocked:
        print("GUARD MEMORY: not started: " + blocked, file=log, flush=True)
        return MEMORY_EXIT
    command = list(command)
    # A console launcher is a tiny parent process; monitor its full editor instead.
    if os.name == "nt" and Path(command[0]).name.endswith("_console.exe"):
        from godot_toolchain import editor_binary
        command[0] = str(editor_binary(command[0]))
    process = subprocess.Popen(command, stdin=subprocess.DEVNULL,
                               stdout=sys.stdout if stdout is None else stdout,
                               stderr=sys.stderr if stderr is None else stderr,
                               start_new_session=(os.name != "nt"))
    started = time.monotonic()
    peak_private = None
    lowest_commit = initial.free_commit if initial is not None else None
    try:
        while True:
            code = process.poll()
            if code is not None:
                return code
            try:
                memory = sample(process.pid)
                if memory is not None:
                    peak_private = max(peak_private or 0, memory.private)
                    lowest_commit = min(lowest_commit if lowest_commit is not None else memory.free_commit, memory.free_commit)
                blocked = reason(memory)
            except OSError:
                if process.poll() is not None:
                    return process.returncode
                raise
            if blocked:
                print("GUARD MEMORY: " + blocked, file=log, flush=True)
                _stop(process)
                return MEMORY_EXIT
            if time.monotonic() - started >= timeout:
                print(f"GUARD TIMEOUT: {timeout:g}s", file=log, flush=True)
                _stop(process)
                return 124
            time.sleep(interval)
    except BaseException:
        _stop(process)
        raise
    finally:
        if peak_private is not None:
            print(f"GUARD STATS: sampled_peak_private_mib={peak_private // MIB} min_free_commit_mib={lowest_commit // MIB}",
                  file=log, flush=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--timeout", type=float, default=900)
    parser.add_argument("--max-private-mib", type=int, default=4096)
    parser.add_argument("--min-free-commit-mib", type=int, default=8192)
    parser.add_argument("--min-free-ram-mib", type=int, default=4096)
    parser.add_argument("command", nargs=argparse.REMAINDER)
    args = parser.parse_args()
    command = args.command[1:] if args.command[:1] == ["--"] else args.command
    if not command or args.timeout <= 0 or min(args.max_private_mib, args.min_free_commit_mib, args.min_free_ram_mib) <= 0:
        parser.error("Supply a command and positive limits")
    return run(command, args.timeout, args.max_private_mib * MIB,
               args.min_free_commit_mib * MIB, args.min_free_ram_mib * MIB)


if __name__ == "__main__":
    raise SystemExit(main())
