using System;
using System.IO;
using System.Net;
using System.Diagnostics;
using System.Security.Cryptography;
using System.Windows.Forms;
using System.Drawing;
using System.ComponentModel;

// Baixador de teste com pacote fixado por SHA256; nao altera o canal estavel.
class Bootstrap : Form {
 const string PackageUrl="PACKAGE_URL";
 const string ExpectedHash="PACKAGE_HASH";
 const long ExpectedSize=PACKAGE_SIZE;
 Label status=new Label(); ProgressBar progress=new ProgressBar(); Button start=new Button();
 WebClient client; string folder; string package; bool busy;
 Bootstrap(){
  Text="TarginoLauncher - Instalacao de teste";ClientSize=new Size(540,210);StartPosition=FormStartPosition.CenterScreen;FormBorderStyle=FormBorderStyle.FixedDialog;MaximizeBox=false;
  Icon=Icon.ExtractAssociatedIcon(Application.ExecutablePath);
  var title=new Label{Text="TarginoLauncher",Font=new Font("Segoe UI",20,FontStyle.Bold),Left=20,Top=18,Width=500,Height=40};
  status.SetBounds(20,65,500,50);status.Text="Previa de teste: baixar, validar e abrir o instalador.\r\nNenhum jogo faz parte deste download.";
  progress.SetBounds(20,120,500,22);start.SetBounds(330,160,190,32);start.Text="Baixar e instalar";start.Click+=StartDownload;
  Controls.AddRange(new Control[]{title,status,progress,start});
  FormClosing+=(s,e)=>{if(busy){e.Cancel=true;status.Text="Cancelando download...";client.CancelAsync();}else if(client!=null)client.Dispose();};
 }
 void StartDownload(object sender,EventArgs e){
  try{
   folder=Path.Combine(Path.GetTempPath(),"TarginoLauncher-Bootstrap-"+Guid.NewGuid().ToString("N"));Directory.CreateDirectory(folder);
   package=Path.Combine(folder,"TarginoLauncher-Setup.exe");
   ServicePointManager.SecurityProtocol=SecurityProtocolType.Tls12;
   client=new WebClient();client.Headers[HttpRequestHeader.UserAgent]="TarginoLauncher-Bootstrap-Test";
   client.DownloadProgressChanged+=(s,a)=>{progress.Value=Math.Max(0,Math.Min(100,a.ProgressPercentage));status.Text="Baixando instalador... "+a.ProgressPercentage+"%";};
   client.DownloadFileCompleted+=Downloaded;
   busy=true;start.Enabled=false;status.Text="Conectando ao GitHub...";
   client.DownloadFileAsync(new Uri(PackageUrl),package);
  }catch(Exception ex){busy=false;start.Enabled=true;status.Text="Falha: "+ex.Message;}
 }
 internal static void ValidatePackage(string path){
  if(new FileInfo(path).Length!=ExpectedSize)throw new IOException("Tamanho do pacote incorreto.");
  using(var sha=SHA256.Create())using(var file=File.OpenRead(path)){
   string actual=BitConverter.ToString(sha.ComputeHash(file)).Replace("-","");
   if(!string.Equals(actual,ExpectedHash,StringComparison.OrdinalIgnoreCase))throw new IOException("Integridade do pacote invalida. Instalacao bloqueada.");
  }
 }
 void Downloaded(object sender,AsyncCompletedEventArgs e){
  busy=false;start.Enabled=true;
  try{
   if(e.Cancelled){status.Text="Download cancelado. Nenhum programa foi instalado.";return;}
   if(e.Error!=null)throw e.Error;
   status.Text="Validando integridade...";ValidatePackage(package);
   using(var installer=Process.Start(new ProcessStartInfo(package){UseShellExecute=true})){
    if(installer==null)throw new IOException("O instalador nao abriu.");
   }
   Close();
  }catch(Exception ex){status.Text="Nao foi possivel instalar: "+ex.Message;}
 }
 [STAThread]static int Main(string[] args){
  if(args.Length==2&&args[0]=="--verify-package"){try{ValidatePackage(args[1]);return 0;}catch{return 1;}}
  Application.EnableVisualStyles();Application.SetCompatibleTextRenderingDefault(false);Application.Run(new Bootstrap());return 0;
 }
}
