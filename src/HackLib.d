module HackLib;

// By Deen O'Connor

pragma(lib, "advapi32");
pragma(lib, "psapi");

import core.sys.windows.windows;
import core.sys.windows.winbase;
import core.sys.windows.tlhelp32;
import core.sys.windows.psapi;
import core.stdc.string;
import std.string;
import std.conv;
import std.stdio;
import core.stdc.stdlib;

class GameProcess {

	PROCESSENTRY32 gameProcess;
	HANDLE processHandle;
	HWND gameWindow;
	uint[string] processModules;

	private wstring targetProcessName;
	private wstring targetWindowName;

	this(string targetProcName, string targetWindName, string[] modules) {
		this.targetProcessName = wtext(targetProcName); 
		this.targetWindowName = wtext(targetWindName);

		foreach (string mod; modules) { // Creating entries for all the modules we want to find in the process
			processModules[mod] = 0;
		}
	}

	~this() {
		dispose();
	}

	public void dispose() {
		CloseHandle(this.processHandle);
	}

	private uint findProcessByName(wstring procName, PROCESSENTRY32 pEntry) {
		PROCESSENTRY32 procEntry;
		procEntry.dwSize = PROCESSENTRY32.sizeof;

		HANDLE hSnapshot = CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
		if (hSnapshot == INVALID_HANDLE_VALUE)
			return 0;

		if (!Process32First(hSnapshot, &procEntry)) {
			CloseHandle(hSnapshot);
			return 0;
		}

		do {
			wstring exeFile = "";
			foreach (wchar single; procEntry.szExeFile) { // szExeFile is a wchar[256] with zeroed chars that are not needed (that's why you need to get rid of them)
				if (single != 0) {
					exeFile ~= single;
				} else break;
			}
			if (procName == exeFile) {
				this.gameProcess = procEntry;
				if (this.gameProcess.th32ProcessID == 0) {
					memcpy(&this.gameProcess, &procEntry, PROCESSENTRY32.sizeof); // Not really needed, left here for safety
				}
				CloseHandle(hSnapshot);
				uint pid = procEntry.th32ProcessID;
				writeln("Game PID is " ~ text(pid));
				return pid;
			}
		}  while (Process32Next(hSnapshot, &procEntry));

		CloseHandle(hSnapshot);
		return 0;
	}

	private uint getThreadByProcess(uint processId) {
		THREADENTRY32 threadEntry;
		threadEntry.dwSize = THREADENTRY32.sizeof;
		HANDLE hSnapshot = CreateToolhelp32Snapshot(TH32CS_SNAPTHREAD, 0);

		if (hSnapshot == INVALID_HANDLE_VALUE)
			return 0;

		if (!Thread32First(hSnapshot, &threadEntry)) {
			CloseHandle(hSnapshot);
			return 0;
		}

		do {
			if (threadEntry.th32OwnerProcessID == processId) {
				CloseHandle(hSnapshot);
				return threadEntry.th32ThreadID;
			}
		} while (Thread32Next(hSnapshot, &threadEntry));
		CloseHandle(hSnapshot);
		return 0;
	}

	private uint getModuleNamePointer(string moduleName, uint processId) {
		MODULEENTRY32 lpModuleEntry = { 0 };
		HANDLE hSnapshot = CreateToolhelp32Snapshot(TH32CS_SNAPMODULE, processId);
		if (hSnapshot == INVALID_HANDLE_VALUE) {
			int code = GetLastError();
			//writeln("System reported code " ~ text(code) ~ " for CreateToolhelp32Snapshot call");
			if (code == 5) {
				//writeln("System reported NotEnoughPrivileges for CreateToolHelp32Snapshot call, please run the hack as administrator!");
				writeln("System reported NotEnoughPrivileges, please run the hack as administrator!");
				readln();
				exit(code);
			}
			return 0;
		}
		lpModuleEntry.dwSize = lpModuleEntry.sizeof;

		int runModule = Module32First(hSnapshot, &lpModuleEntry);
		while (runModule != 0) {
			wstring modulename = "";
			foreach (wchar single; lpModuleEntry.szModule) {
				if(single != 0) {
					modulename ~= single;
				} else break;
			}
			if (modulename == wtext(moduleName)) {
				CloseHandle(hSnapshot);
				return cast(uint)lpModuleEntry.modBaseAddr;
			}
			runModule = Module32Next(hSnapshot, &lpModuleEntry);
		}
		CloseHandle(hSnapshot);
		return 0;
	}

	private void setDebugPrivileges() {
		HANDLE procHandle = GetCurrentProcess(), handleToken;
		TOKEN_PRIVILEGES priv;
		LUID luid;
		OpenProcessToken(procHandle, TOKEN_ADJUST_PRIVILEGES, &handleToken);
		wstring wstr = wtext("SeDebugPrivilege");
		LookupPrivilegeValue(null, cast(wchar*)&wstr, &luid);
		priv.PrivilegeCount = 1;
		priv.Privileges[0].Luid = luid;
		priv.Privileges[0].Attributes = SE_PRIVILEGE_ENABLED;
		uint rnd = 0;
		AdjustTokenPrivileges(handleToken, 0, &priv, 0, null, &rnd);
		CloseHandle(handleToken);
		CloseHandle(procHandle);
	}

	private int getProcessModuleCount(HANDLE procHandle) {
		int moduleCount = 0;
		HMODULE[1024] procModules;
		uint cbNeeded;
		bool result = EnumProcessModules(procHandle, cast(void**)&procModules, procModules.sizeof, &cbNeeded) != 0; // Enumerating all modules and converting the exit value to a real boolean

		if (result) {
			foreach (HMODULE hmdl; procModules) {
				TCHAR[260] szModName; // 260 is MAX_PATH actual value
				if (GetModuleFileNameEx(procHandle, hmdl, cast(TCHAR*)&szModName, 260) != 0) { // If such module exists in target process
					moduleCount++;
				}
			}
		}
		return moduleCount;
	}

	public void runOnProcess() {
		this.setDebugPrivileges();
		writeln("Waiting for the game to appear...");
		while (this.findProcessByName(this.targetProcessName, this.gameProcess) == 0) {
			Sleep(10);
		}
		while (this.getThreadByProcess(gameProcess.th32ProcessID) == 0) {
			Sleep(10);
		}

		this.processHandle = OpenProcess(PROCESS_ALL_ACCESS, false, gameProcess.th32ProcessID);

		int modCount = this.getProcessModuleCount(this.processHandle);
		foreach (string moduleName; this.processModules.byKey()) { // Excluded for loop for now. If you want, just uncomment all the lines inside this foreach loop.
			uint modPtr = 0x0;
			//for (int i = 0; i < modCount; i++) { // Iterating as many times as many modules are loaded in the process. Normally there'll be one iteration for one module.
				modPtr = this.getModuleNamePointer(moduleName, this.gameProcess.th32ProcessID);
				if (modPtr != 0x0) {
					this.processModules[moduleName] = modPtr;
					//break;
					continue;
				}
			//}
			//if (modPtr == 0x0)
				this.processModules.remove(moduleName); // Deleting key for a module if it has not been found
		}

		wstring wstr = wtext(this.targetWindowName);
		gameWindow = FindWindow(null, cast(wchar*)&wstr);
	}
}