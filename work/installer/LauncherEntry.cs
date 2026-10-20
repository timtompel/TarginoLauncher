using System;
using System.Diagnostics;
using System.IO;
using System.Windows.Forms;
class LauncherEntry {
 [STAThread] static void Main(){
  try {
   string root=AppDomain.CurrentDomain.BaseDirectory;
   string script=Path.Combine(root,"src","CentralArquivista.ps1");
   if(!File.Exists(script))throw new FileNotFoundException("Arquivos do launcher ausentes. Reinstale o pacote.");
   string powershell=Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.Windows),"System32","WindowsPowerShell","v1.0","powershell.exe");
   var info=new ProcessStartInfo(powershell,"-NoProfile -STA -ExecutionPolicy Bypass -WindowStyle Hidden -File \""+script+"\"");
   info.WorkingDirectory=root;info.UseShellExecute=false;info.CreateNoWindow=true;
   Process.Start(info);
  }catch(Exception e){MessageBox.Show(e.Message,"TarginoLauncher",MessageBoxButtons.OK,MessageBoxIcon.Error);}
 }
}
