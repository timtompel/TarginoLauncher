using System;
using System.IO;
using System.Reflection;
using System.Windows.Forms;
using Microsoft.Win32;
class Uninstall {
 internal static void CleanEmptyProgramFolders(string root){
  foreach(string name in new[]{"src","Recursos"}){
   string folder=Path.Combine(Path.GetFullPath(root),name);
   if(Directory.Exists(folder))CleanEmptyFolder(new DirectoryInfo(folder));
  }
 }
 static void CleanEmptyFolder(DirectoryInfo folder){
  if((folder.Attributes&FileAttributes.ReparsePoint)!=0)return;
  foreach(var child in folder.GetDirectories())CleanEmptyFolder(child);
  if(folder.GetFileSystemInfos().Length==0)folder.Delete();
 }
 internal static string GetLibraryForRemoval(string root){
  root=Path.GetFullPath(root).TrimEnd('\\');
  string library=Path.GetFullPath(Path.Combine(root,"Biblioteca"));
  if(!string.Equals(Path.GetDirectoryName(library),root,StringComparison.OrdinalIgnoreCase))throw new IOException("Biblioteca fora da instalacao.");
  for(var parent=new DirectoryInfo(library);parent!=null;parent=parent.Parent){if(parent.Exists&&(parent.Attributes&FileAttributes.ReparsePoint)!=0)throw new IOException("Biblioteca com link nao permitida.");}
  if(Directory.Exists(library))ValidateTree(new DirectoryInfo(library));
  return library;
 }
 static void ValidateTree(DirectoryInfo folder){
  foreach(var item in folder.GetFileSystemInfos()){
   if((item.Attributes&FileAttributes.ReparsePoint)!=0)throw new IOException("Biblioteca contem links. Remocao automatica bloqueada.");
   if(item is DirectoryInfo)ValidateTree((DirectoryInfo)item);
  }
 }
 static bool ConfirmRemoval(out bool removeGames){
  using(var dialog=new Form()){
   dialog.Text="Desinstalar TarginoLauncher";dialog.ClientSize=new System.Drawing.Size(540,210);dialog.StartPosition=FormStartPosition.CenterScreen;dialog.FormBorderStyle=FormBorderStyle.FixedDialog;dialog.MaximizeBox=false;dialog.MinimizeBox=false;
   var text=new Label{Text="Remover o launcher? Configuracoes e backups serao preservados.\r\nO programa original do Central Arquivista nao sera alterado.",Left=20,Top=20,Width=500,Height=48};
   var games=new CheckBox{Text="Remover tambem os jogos da Biblioteca deste launcher",Left=20,Top=78,Width=500,Checked=false};
   var note=new Label{Text="Inclui saves dentro das pastas dos jogos. Serao enviados a Lixeira.\r\nJogos em pastas externas nao serao removidos.",Left=20,Top=108,Width=500,Height=40};
   var yes=new Button{Text="Desinstalar",Left=290,Top=165,Width=110,DialogResult=DialogResult.OK};
   var no=new Button{Text="Cancelar",Left=410,Top=165,Width=110,DialogResult=DialogResult.Cancel};
   dialog.Controls.AddRange(new Control[]{text,games,note,yes,no});dialog.CancelButton=no;dialog.AcceptButton=no;
   bool confirmed=dialog.ShowDialog()==DialogResult.OK;removeGames=confirmed&&games.Checked;return confirmed;
  }
 }
 static void RemoveShortcut(string path,string expected){
  if(!File.Exists(path))return;
  Type type=Type.GetTypeFromProgID("WScript.Shell");object shell=Activator.CreateInstance(type);object link=type.InvokeMember("CreateShortcut",BindingFlags.InvokeMethod,null,shell,new object[]{path});
   try{
    string target=(string)link.GetType().InvokeMember("TargetPath",BindingFlags.GetProperty,null,link,null);
    string arguments=(string)link.GetType().InvokeMember("Arguments",BindingFlags.GetProperty,null,link,null);
    string legacyScript=Path.Combine(Path.GetDirectoryName(expected),"src","CentralArquivista.ps1");
    bool legacy=string.Equals(Path.GetFileName(target),"powershell.exe",StringComparison.OrdinalIgnoreCase)&&arguments.IndexOf("\""+legacyScript+"\"",StringComparison.OrdinalIgnoreCase)>=0;
    if(string.Equals(target,expected,StringComparison.OrdinalIgnoreCase)||legacy)File.Delete(path);
   }
  finally{System.Runtime.InteropServices.Marshal.ReleaseComObject(link);System.Runtime.InteropServices.Marshal.ReleaseComObject(shell);}
 }
 [STAThread] static void Main(){
  string root=AppDomain.CurrentDomain.BaseDirectory.TrimEnd('\\');
  try{
   string manifest=Path.Combine(root,"frontend.manifest");string[] lines=File.ReadAllLines(manifest);
   if(lines.Length<2||lines[0]!="TarginoLauncher.Recompilados")throw new IOException("Manifesto de instalacao invalido.");
   string locked=Path.Combine(root,"Dados","launcher.lock");if(File.Exists(locked)){using(var check=new FileStream(locked,FileMode.Open,FileAccess.ReadWrite,FileShare.None)){} }
   bool removeGames;if(!ConfirmRemoval(out removeGames))return;
   if(removeGames){
    string library=GetLibraryForRemoval(root);
    if(Directory.Exists(library))Microsoft.VisualBasic.FileIO.FileSystem.DeleteDirectory(library,Microsoft.VisualBasic.FileIO.UIOption.OnlyErrorDialogs,Microsoft.VisualBasic.FileIO.RecycleOption.SendToRecycleBin,Microsoft.VisualBasic.FileIO.UICancelOption.ThrowException);
   }
   foreach(string rel in lines){
    if(rel==lines[0]||rel.StartsWith("version=")||rel=="Desinstalar.exe"||rel=="frontend.manifest")continue;
    if(Path.IsPathRooted(rel)||rel.Contains(":")||Array.IndexOf(rel.Split('\\'),"..")>=0)throw new IOException("Caminho invalido no manifesto.");
    if(!(rel.StartsWith("src\\")||rel.StartsWith("Recursos\\Plataformas\\")||rel.StartsWith("Recursos\\Controles\\")||rel=="Recursos\\TarginoLauncher.ico"||rel=="TarginoLauncher-Recompilados.exe"||rel=="LEIA-ME.txt"||rel=="file-hashes.txt"||rel=="versao.json"))continue;
    string file=Path.GetFullPath(Path.Combine(root,rel));if(!file.StartsWith(root+"\\",StringComparison.OrdinalIgnoreCase))throw new IOException("Arquivo fora da instalacao.");
    for(var parent=new DirectoryInfo(Path.GetDirectoryName(file));parent!=null&&parent.FullName.Length>=root.Length;parent=parent.Parent){if(parent.Exists&&(parent.Attributes&FileAttributes.ReparsePoint)!=0)throw new IOException("Pasta com link nao permitida.");}
    if(File.Exists(file))File.Delete(file);
   }
   string exe=Path.Combine(root,"TarginoLauncher-Recompilados.exe");
   RemoveShortcut(Path.Combine(root,"Abrir Launcher.lnk"),exe);
   RemoveShortcut(Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.DesktopDirectory),"TarginoLauncher - Recompilados.lnk"),exe);
   RemoveShortcut(Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.StartMenu),"Programs","TarginoLauncher - Recompilados","TarginoLauncher - Recompilados.lnk"),exe);
   string keyName="Software\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\TarginoLauncherRecompilados";
   bool own=false;using(var key=Registry.CurrentUser.OpenSubKey(keyName)){own=key!=null&&string.Equals((string)key.GetValue("InstallLocation"),root,StringComparison.OrdinalIgnoreCase);}
   if(own)Registry.CurrentUser.DeleteSubKeyTree(keyName);
   CleanEmptyProgramFolders(root);
   MessageBox.Show("Frontend removido. Dados e backups foram mantidos.\r\n"+(removeGames?"Biblioteca enviada para a Lixeira.":"Jogos preservados.")+"\r\nO desinstalador e o manifesto permanecem para permitir reinstalacao.","TarginoLauncher");
  }catch(Exception e){MessageBox.Show(e.Message,"Nao foi possivel desinstalar",MessageBoxButtons.OK,MessageBoxIcon.Error);}
 }
}
