using System;
using System.Runtime.InteropServices;
namespace TarginoLauncher {
 public static class WindowIdentity {
  public const string AppId="TarginoLauncher.Recompilados.Desktop";
  [DllImport("shell32.dll",CharSet=CharSet.Unicode)]static extern int SetCurrentProcessExplicitAppUserModelID(string id);
  [DllImport("shell32.dll")]static extern int GetCurrentProcessExplicitAppUserModelID(out IntPtr id);
  public static void Initialize(){Marshal.ThrowExceptionForHR(SetCurrentProcessExplicitAppUserModelID(AppId));}
  public static string Current(){
   IntPtr value;Marshal.ThrowExceptionForHR(GetCurrentProcessExplicitAppUserModelID(out value));
   try{return Marshal.PtrToStringUni(value);}finally{Marshal.FreeCoTaskMem(value);}
  }
 }
}
