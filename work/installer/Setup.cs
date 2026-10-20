using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Drawing;
using System.IO;
using System.IO.Compression;
using System.Reflection;
using System.Security.Cryptography;
using System.Text;
using System.Windows.Forms;
using Microsoft.Win32;
public class Setup : Form {
 public const string Product="TarginoLauncher - Recompilados by Central Arquivista";
 public const string Version="0.1.0-preview.2";
 public const string Marker="TarginoLauncher.Recompilados";
 TextBox destination; Button install; Label status; CheckBox desktop;
 public Setup(){
  Text=Product+" - Instalador";Icon=Icon.ExtractAssociatedIcon(Application.ExecutablePath);ClientSize=new Size(800,730);MinimumSize=new Size(816,769);StartPosition=FormStartPosition.CenterScreen;
  BackColor=Color.FromArgb(17,24,33);ForeColor=Color.White;Font=new Font("Segoe UI",10);AutoScaleMode=AutoScaleMode.Dpi;
  var banner=new PictureBox{Left=0,Top=0,Width=800,Height=300,SizeMode=PictureBoxSizeMode.Zoom,Anchor=AnchorStyles.Top|AnchorStyles.Left|AnchorStyles.Right,BackColor=Color.Black,Image=ResourceImage("banner.png")};Controls.Add(banner);
  var avatar=new PictureBox{Left=22,Top=316,Width=96,Height=100,SizeMode=PictureBoxSizeMode.Zoom,Image=ResourceImage("avatar.png")};Controls.Add(avatar);
  Controls.Add(new Label{Left=136,Top=322,Width=635,Height=60,Text=Product,Font=new Font("Segoe UI",18,FontStyle.Bold)});
  Controls.Add(new Label{Left=138,Top=386,Width=610,Height=28,Text=(Version.Contains("-")?"Previa de testes ":"Versao ")+Version+"  |  Windows x64"});
  Controls.Add(new Label{Left=24,Top=434,Width=748,Height=50,Text="Instala somente o frontend. Conecte depois sua biblioteca do Central original.\r\nJogos, saves, catalogos pessoais e contas nao fazem parte deste pacote."});
  Controls.Add(new Label{Left=24,Top=492,Width=500,Height=25,Text="Pasta de instalacao (separada do Central original):"});
  destination=new TextBox{Left=24,Top=522,Width=636,BackColor=Color.White,ForeColor=Color.Black,Text=Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),"Programs","TarginoLauncher-Recompilados")};Controls.Add(destination);
  var browse=new Button{Left=670,Top=519,Width=106,Height=32,Text="Procurar..."};browse.Click+=(s,e)=>{using(var d=new FolderBrowserDialog()){d.Description="Escolha uma pasta vazia para o novo launcher.";if(d.ShowDialog()==DialogResult.OK)destination.Text=d.SelectedPath;}};Controls.Add(browse);
  desktop=new CheckBox{Left=24,Top=564,Width=600,Text="Criar atalho na area de trabalho",Checked=true};Controls.Add(desktop);
  Controls.Add(new Label{Left=24,Top=599,Width=746,Height=38,ForeColor=Color.LightSteelBlue,Text="Instalador sem assinatura digital de editor. Artes: CC BY-NC-SA; creditos incluidos.\r\n"+(Version.Contains("-")?"Esta previa ainda nao e uma versao estavel.":"Atualizacoes do launcher preservam dados e biblioteca.")});
  status=new Label{Left=24,Top=646,Width=540,Height=60};Controls.Add(status);
  install=new Button{Left=604,Top=655,Width=172,Height=44,Text="Instalar",BackColor=Color.FromArgb(0,120,180),ForeColor=Color.White,FlatStyle=FlatStyle.Flat};
  install.Click+=(s,e)=>InstallClicked();Controls.Add(install);
 }
 static Image ResourceImage(string name){using(var stream=Assembly.GetExecutingAssembly().GetManifestResourceStream(name)){using(var image=Image.FromStream(stream))return new Bitmap(image);}}
 void InstallClicked(){
  install.Enabled=false;status.Text="Verificando e instalando...";Refresh();
  try{
   string target=Path.GetFullPath(destination.Text.Trim());InstallTo(target);
   Register(target,desktop.Checked);
   status.Text="Instalacao concluida. Seus dados ficam nesta pasta.";
   install.Text="Concluir";install.Enabled=true;
   if(MessageBox.Show("Instalacao concluida. Deseja abrir o launcher agora?",Product,MessageBoxButtons.YesNo,MessageBoxIcon.Question)==DialogResult.Yes){Process.Start(Path.Combine(target,"TarginoLauncher-Recompilados.exe"));}
   Close();
  }catch(Exception ex){status.Text="Instalacao nao concluida.";install.Enabled=true;MessageBox.Show(ex.Message,Product,MessageBoxButtons.OK,MessageBoxIcon.Error);}
 }
 static void CheckDestination(string target){
  string full=Path.GetFullPath(target).TrimEnd(Path.DirectorySeparatorChar);
  if(full.Length<5||full==Path.GetPathRoot(full).TrimEnd('\\'))throw new IOException("Escolha uma pasta propria para o launcher.");
  for(DirectoryInfo d=new DirectoryInfo(full);d!=null;d=d.Parent){
   if(d.Exists&&(d.Attributes&FileAttributes.ReparsePoint)!=0)throw new IOException("Pasta de instalacao com links nao permitida.");
   if(Directory.Exists(Path.Combine(d.FullName,"Arquivismo"))&&Directory.Exists(Path.Combine(d.FullName,"Jogos")))throw new IOException("Escolha uma pasta fora da instalacao do Central original.");
  }
  string manifest=Path.Combine(full,"frontend.manifest");
  if(Directory.Exists(full)&&Directory.GetFileSystemEntries(full).Length>0&&!File.Exists(manifest))throw new IOException("A pasta possui outros arquivos. Escolha uma pasta vazia ou uma instalacao feita por este instalador.");
  if(File.Exists(manifest)&&File.ReadAllLines(manifest)[0]!=Marker)throw new IOException("A pasta nao pertence a este produto.");
  string file=Path.Combine(full,"Dados","launcher.lock");
  if(File.Exists(file)){using(var locked=new FileStream(file,FileMode.Open,FileAccess.ReadWrite,FileShare.None)){} }
 }
 public static void ValidateFreeSpace(long available,long required){
  if(available<0||required<0||available<required)throw new IOException("Espaco livre insuficiente para instalar e preservar o backup. Nenhum arquivo do launcher foi substituido.");
 }
 public static void InstallTo(string target){
  target=Path.GetFullPath(target);CheckDestination(target);
  string stage=Path.Combine(Path.GetTempPath(),"TarginoSetup-"+Guid.NewGuid().ToString("N"));Directory.CreateDirectory(stage);
  var files=new List<string>();var copied=new List<string>();var old=new HashSet<string>(StringComparer.OrdinalIgnoreCase);
  string backup=Path.Combine(target,"BackupsFrontend",DateTime.Now.ToString("yyyyMMdd-HHmmss")+"-"+Guid.NewGuid().ToString("N").Substring(0,6));
  bool committed=false;FileStream installLock=null;
  try{
   using(var stream=Assembly.GetExecutingAssembly().GetManifestResourceStream("payload.zip"))
   using(var zip=new ZipArchive(stream,ZipArchiveMode.Read)){
    long total=0;
    foreach(var entry in zip.Entries){
     string rel=entry.FullName.Replace('/','\\');
     if(rel.Length==0||rel.EndsWith("\\"))continue;
     if(Path.IsPathRooted(rel)||rel.Contains(":")||Array.IndexOf(rel.Split('\\'),"..")>=0||((entry.ExternalAttributes>>16)&0xF000)==0xA000)throw new IOException("Caminho invalido no pacote.");
     if(!(rel.StartsWith("src\\",StringComparison.OrdinalIgnoreCase)||rel.StartsWith("Recursos\\Plataformas\\",StringComparison.OrdinalIgnoreCase)||rel.StartsWith("Recursos\\Controles\\",StringComparison.OrdinalIgnoreCase)||rel=="Recursos\\TarginoLauncher.ico"||rel=="TarginoLauncher-Recompilados.exe"||rel=="Desinstalar.exe"||rel=="LEIA-ME.txt"||rel=="frontend.manifest"||rel=="file-hashes.txt"||rel=="versao.json"))throw new IOException("Arquivo nao permitido no pacote.");
     total+=entry.Length;if(total>64*1024*1024)throw new IOException("Pacote excede limite de tamanho.");
     string path=Path.Combine(stage,rel);Directory.CreateDirectory(Path.GetDirectoryName(path));entry.ExtractToFile(path);files.Add(rel);
    }
   }
   var verified=new HashSet<string>(StringComparer.OrdinalIgnoreCase);
   foreach(string line in File.ReadAllLines(Path.Combine(stage,"file-hashes.txt"))){
    int split=line.IndexOf("  ",StringComparison.Ordinal);if(split<0)throw new IOException("Manifesto de hashes invalido.");
    string hash=line.Substring(0,split),rel=line.Substring(split+2);if(!files.Contains(rel)||!verified.Add(rel))throw new IOException("Arquivo de hash inesperado.");
    using(var sha=SHA256.Create())using(var input=File.OpenRead(Path.Combine(stage,rel))){string got=BitConverter.ToString(sha.ComputeHash(input)).Replace("-","");if(!got.Equals(hash,StringComparison.OrdinalIgnoreCase))throw new IOException("Integridade invalida: "+rel);}
   }
   if(verified.Count!=files.Count-1)throw new IOException("Manifesto incompleto.");
   // O .NET Framework/PowerShell usados pelo launcher nao garantem caminhos longos.
   // Verificar tambem o caminho do backup ANTES de substituir qualquer arquivo.
   foreach(string rel in files){
    string output=Path.Combine(target,rel),bak=Path.Combine(backup,rel);
    if(output.Length>=260||bak.Length>=260||Path.GetDirectoryName(output).Length>=248||Path.GetDirectoryName(bak).Length>=248)throw new IOException("Pasta muito profunda para instalacao e backup. Escolha um caminho mais curto. Nenhum arquivo do launcher foi substituido.");
   }
   long required=8L*1024*1024;
   foreach(string rel in files){required+=new FileInfo(Path.Combine(stage,rel)).Length;string previous=Path.Combine(target,rel);if(File.Exists(previous))required+=new FileInfo(previous).Length;}
   ValidateFreeSpace(new DriveInfo(Path.GetPathRoot(target)).AvailableFreeSpace,required);
   Directory.CreateDirectory(target);
   Directory.CreateDirectory(Path.Combine(target,"Dados"));
   installLock=new FileStream(Path.Combine(target,"Dados","launcher.lock"),FileMode.OpenOrCreate,FileAccess.ReadWrite,FileShare.None);
   foreach(string rel in files){
    string output=Path.Combine(target,rel);Directory.CreateDirectory(Path.GetDirectoryName(output));
    var parent=new DirectoryInfo(Path.GetDirectoryName(output));while(parent!=null&&parent.FullName.Length>=target.Length){if((parent.Attributes&FileAttributes.ReparsePoint)!=0)throw new IOException("Destino com link nao permitido.");parent=parent.Parent;}
    if(File.Exists(output)){if((File.GetAttributes(output)&FileAttributes.ReparsePoint)!=0)throw new IOException("Arquivo de destino com link nao permitido.");string bak=Path.Combine(backup,rel);Directory.CreateDirectory(Path.GetDirectoryName(bak));File.Copy(output,bak);old.Add(rel);}
    copied.Add(rel);File.Copy(Path.Combine(stage,rel),output,true);
   }
   var obsolete=new List<string>(new[]{"src\\MetadataWorker.ps1","src\\MetadataMatch.ps1","src\\BaseUpdateWorker.ps1.antes-interface","src\\CentralArquivista.ps1.antes-interface","src\\Input.ps1.antes-interface","src\\OrganizedUI.ps1.antes-interface"});
   foreach(string rel in files){if(rel.StartsWith("Recursos\\Plataformas\\",StringComparison.OrdinalIgnoreCase)&&rel.EndsWith(".png",StringComparison.OrdinalIgnoreCase))obsolete.Add(Path.ChangeExtension(rel,".svg"));}
   foreach(string rel in obsolete){
    string dest=Path.Combine(target,rel);if(!File.Exists(dest))continue;
    if((File.GetAttributes(dest)&FileAttributes.ReparsePoint)!=0)throw new IOException("Arquivo antigo com link nao permitido.");
    string bak=Path.Combine(backup,rel);Directory.CreateDirectory(Path.GetDirectoryName(bak));File.Copy(dest,bak);old.Add(rel);copied.Add(rel);File.Delete(dest);
   }
   committed=true;
  }finally{
   try{
    if(!committed){
     var failures=new List<string>();
     foreach(string rel in copied){try{string dest=Path.Combine(target,rel);if(old.Contains(rel))File.Copy(Path.Combine(backup,rel),dest,true);else if(File.Exists(dest))File.Delete(dest);}catch{failures.Add(rel);}}
     if(failures.Count>0)throw new IOException("Recuperacao parcial. Preserve o backup em "+backup+". Arquivos: "+string.Join(", ",failures.ToArray()));
    }
   }finally{
    if(installLock!=null)installLock.Dispose();
    // Apenas o diretorio temporario gerado por esta operacao.
    if(Directory.Exists(stage))Directory.Delete(stage,true);
   }
  }
 }
 static void Shortcut(string path,string executable,string root){
  Type type=Type.GetTypeFromProgID("WScript.Shell");object shell=Activator.CreateInstance(type);
  object link=type.InvokeMember("CreateShortcut",BindingFlags.InvokeMethod,null,shell,new object[]{path});
  try{Type t=link.GetType();t.InvokeMember("TargetPath",BindingFlags.SetProperty,null,link,new object[]{executable});t.InvokeMember("WorkingDirectory",BindingFlags.SetProperty,null,link,new object[]{root});t.InvokeMember("IconLocation",BindingFlags.SetProperty,null,link,new object[]{Path.Combine(root,"Recursos","TarginoLauncher.ico")});t.InvokeMember("Save",BindingFlags.InvokeMethod,null,link,null);}
  finally{System.Runtime.InteropServices.Marshal.ReleaseComObject(link);System.Runtime.InteropServices.Marshal.ReleaseComObject(shell);}
 }
 static void Register(string target,bool desktop){
  string exe=Path.Combine(target,"TarginoLauncher-Recompilados.exe");string menu=Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.StartMenu),"Programs","TarginoLauncher - Recompilados");Directory.CreateDirectory(menu);
  Shortcut(Path.Combine(menu,"TarginoLauncher - Recompilados.lnk"),exe,target);
  string desktopLink=Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.DesktopDirectory),"TarginoLauncher - Recompilados.lnk");
  if(desktop||File.Exists(desktopLink))Shortcut(desktopLink,exe,target);
  Shortcut(Path.Combine(target,"Abrir Launcher.lnk"),exe,target);
  using(var key=Registry.CurrentUser.CreateSubKey("Software\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\TarginoLauncherRecompilados")){
   key.SetValue("DisplayName",Product);key.SetValue("DisplayVersion",Version);key.SetValue("Publisher","Targino.SocialMedia");key.SetValue("InstallLocation",target);key.SetValue("DisplayIcon",exe);key.SetValue("UninstallString","\""+Path.Combine(target,"Desinstalar.exe")+"\"");key.SetValue("NoModify",1);key.SetValue("NoRepair",1);
  }
 }
 [STAThread] static int Main(string[] args){
  bool testApply=args.Length==3&&args[0]=="--test-apply-update";
  if(args.Length==3&&(args[0]=="--apply-update"||testApply)){
   string root=Path.GetFullPath(args[1]);
   try{
    int pid;if(!int.TryParse(args[2],out pid)||pid<=0)throw new IOException("Processo de origem invalido.");
    string marker=Path.Combine(root,"frontend.manifest");
    if(!File.Exists(marker)||File.ReadAllLines(marker)[0]!=Marker)throw new IOException("Instalacao de destino nao reconhecida. Use o instalador para a primeira instalacao.");
    try{using(var parent=Process.GetProcessById(pid)){if(!parent.WaitForExit(60000))throw new IOException("O launcher nao fechou. Atualizacao cancelada.");}}catch(ArgumentException){}
    InstallTo(root);
    if(testApply){
     string shell=Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.Windows),"System32","WindowsPowerShell","v1.0","powershell.exe");
     var info=new ProcessStartInfo(shell,"-NoProfile -STA -ExecutionPolicy Bypass -File \""+Path.Combine(root,"src","CentralArquivista.ps1")+"\" -VerifyClean");info.UseShellExecute=false;info.CreateNoWindow=true;
     using(var restarted=Process.Start(info)){if(!restarted.WaitForExit(60000)||restarted.ExitCode!=0)throw new IOException("Reabertura de teste falhou.");}
    }else{Register(root,false);Process.Start(Path.Combine(root,"TarginoLauncher-Recompilados.exe"));}
    return 0;
   }catch(Exception ex){if(testApply)Console.Error.WriteLine(ex.Message);else MessageBox.Show("Atualizacao nao concluida. Os arquivos substituidos foram restaurados quando possivel.\r\n"+ex.Message,Product,MessageBoxButtons.OK,MessageBoxIcon.Error);return 1;}
  }
  if(args.Length==2&&args[0]=="--test-install"){try{InstallTo(args[1]);return 0;}catch(Exception e){Console.Error.WriteLine(e.Message);return 1;}}
  Application.EnableVisualStyles();Application.SetCompatibleTextRenderingDefault(false);Application.Run(new Setup());return 0;
 }
}
