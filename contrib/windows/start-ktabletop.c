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

    char szBinPath[MAX_PATH];
    char szCmdLine[MAX_PATH + 32];
    snprintf(szBinPath, sizeof(szBinPath), "%s\\bin", szPath);
    snprintf(szCmdLine, sizeof(szCmdLine), "\"%s\\ktabletop-app.exe\"", szBinPath);

    char szOldPath[4096];
    DWORD dwLen = GetEnvironmentVariableA("PATH", szOldPath, sizeof(szOldPath));
    if (dwLen > 0 && dwLen < sizeof(szOldPath)) {
        char szNewPath[8192];
        snprintf(szNewPath, sizeof(szNewPath), "%s;%s", szBinPath, szOldPath);
        SetEnvironmentVariableA("PATH", szNewPath);
    }

    SetCurrentDirectoryA(szPath);

    STARTUPINFOA si = {sizeof(si)};
    PROCESS_INFORMATION pi = {0};

    BOOL bSuccess = CreateProcessA(NULL, szCmdLine, NULL, NULL, FALSE, 0, NULL, szBinPath, &si, &pi);

    if (!bSuccess) {
        char szErrorMsg[256];
        snprintf(szErrorMsg,
                 sizeof(szErrorMsg),
                 "Error at start ktabletop-app.exe (error: %lu).\nCheck that it exists in bin\\ktabletop-app.exe.",
                 GetLastError());
        MessageBoxA(NULL, szErrorMsg, "KTabletop", MB_OK | MB_ICONERROR);
        return 1;
    }

    CloseHandle(pi.hProcess);
    CloseHandle(pi.hThread);

    return 0;
}
