#include <stdio.h>
#include <string.h>
#include <windows.h>

int WINAPI WinMain(HINSTANCE hInstance, HINSTANCE hPrevInstance, LPSTR lpCmdLine, int nCmdShow)
{
    char szPath[MAX_PATH];
    if (!GetModuleFileNameA(NULL, szPath, MAX_PATH)) {
        return 1;
    }

    char *pLastSlash = strrchr(szPath, '\\');
    if (pLastSlash) {
        *pLastSlash = '\0';
    }

    SetCurrentDirectoryA(szPath);

    STARTUPINFOA si = {sizeof(si)};
    PROCESS_INFORMATION pi = {0};

    char szCmdLine[] = ".\\bin\\ktabletop.exe";

    BOOL bSuccess = CreateProcessA(NULL, szCmdLine, NULL, NULL, FALSE, 0, NULL, NULL, &si, &pi);

    if (!bSuccess) {
        char szErrorMsg[256];
        snprintf(szErrorMsg, sizeof(szErrorMsg), "Error at start ktabletop.exe (error: %lu).\nCheck if it exists in bin\\ktabletop.exe.", GetLastError());
        MessageBoxA(NULL, szErrorMsg, "KTabletop", MB_OK | MB_ICONERROR);
        return 1;
    }

    CloseHandle(pi.hProcess);
    CloseHandle(pi.hThread);

    return 0;
}
