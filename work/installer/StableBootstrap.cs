using System;
using System.IO;
using System.Net;
using System.Text;
using System.Text.RegularExpressions;
using System.Collections.Generic;
using System.Security.Cryptography;
using System.Web.Script.Serialization;
using System.ComponentModel;
using System.Diagnostics;
using System.Drawing;
using System.Reflection;
using System.Windows.Forms;

public sealed class StableBootstrapPackage {
 public string Version, FileName, Url, Hash;
 public long Size;
}
public static class StableBootstrapSecurity {
 const string PublicKeyBase64="PUBLIC_KEY_BASE64";
 const string Repository="https://github.com/timtompel/TarginoLauncher";
 public const string Latest="https://api.github.com/repos/timtompel/TarginoLauncher/releases/latest";
 static Dictionary<string,object> Json(string text){
  var serializer=new JavaScriptSerializer{MaxJsonLength=1048576,RecursionLimit=32};
  var result=serializer.DeserializeObject(text) as Dictionary<string,object>;
  if(result==null)throw new IOException("JSON invalido.");return result;
 }
 static string Text(Dictionary<string,object> data,string key){object value;if(!data.TryGetValue(key,out value)||!(value is string))throw new IOException("Campo ausente: "+key);return (string)value;}
 static bool Flag(Dictionary<string,object> data,string key){object value;if(!data.TryGetValue(key,out value)||!(value is bool))throw new IOException("Indicador ausente: "+key);return (bool)value;}
 static long Number(Dictionary<string,object> data,string key){object value;long result;if(!data.TryGetValue(key,out value)||value is bool||!long.TryParse(Convert.ToString(value,System.Globalization.CultureInfo.InvariantCulture),out result))throw new IOException("Numero invalido: "+key);return result;}
 public static void ValidateVersion(string version){if(!Regex.IsMatch(version,@"^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$"))throw new IOException("Versao estavel invalida.");}
 public static void ValidateUrl(string url,string version,string file){if(url!=Repository+"/releases/download/v"+version+"/"+file)throw new IOException("Origem nao autorizada.");}
 public static string ReleaseVersion(string json){var release=Json(json);if(Flag(release,"draft")||Flag(release,"prerelease"))throw new IOException("A release nao e estavel.");string tag=Text(release,"tag_name");if(!tag.StartsWith("v"))throw new IOException("Tag invalida.");string version=tag.Substring(1);ValidateVersion(version);return version;}
 public static StableBootstrapPackage ReadManifest(string json){
  if(Encoding.UTF8.GetByteCount(json)>65536)throw new IOException("Manifesto excede o limite.");
  var envelope=Json(json);if(Text(envelope,"algorithm")!="RSA-SHA256")throw new IOException("Algoritmo nao suportado.");
  byte[] payload=Convert.FromBase64String(Text(envelope,"payload")),signature=Convert.FromBase64String(Text(envelope,"signature"));
  using(var rsa=new RSACryptoServiceProvider()){
   rsa.PersistKeyInCsp=false;rsa.FromXmlString(Encoding.UTF8.GetString(Convert.FromBase64String(PublicKeyBase64)));
   if(rsa.KeySize<3072||!rsa.VerifyData(payload,"SHA256",signature))throw new IOException("Assinatura invalida. Instalacao bloqueada.");
  }
  var data=Json(Encoding.UTF8.GetString(payload));string version=Text(data,"version");ValidateVersion(version);
  if(Number(data,"schemaVersion")!=1||Text(data,"product")!="TarginoLauncher.Recompilados"||Text(data,"channel")!="stable")throw new IOException("Manifesto de outro produto/canal.");
  var package=new StableBootstrapPackage{Version=version,FileName=Text(data,"fileName"),Url=Text(data,"url"),Size=Number(data,"size"),Hash=Text(data,"sha256")};
  if(package.FileName!="TarginoLauncher-Recompilados-"+version+"-Setup.exe"||package.Size<1024||package.Size>67108864||!Regex.IsMatch(package.Hash,"^[A-Fa-f0-9]{64}$"))throw new IOException("Dados do pacote invalidos.");
  ValidateUrl(package.Url,version,package.FileName);return package;
 }
 public static void ValidatePackage(string path,StableBootstrapPackage package){
  using(var file=new FileStream(path,FileMode.Open,FileAccess.Read,FileShare.Read)){
   if(file.Length!=package.Size)throw new IOException("Pacote incompleto.");
   using(var sha=SHA256.Create()){
    string actual=BitConverter.ToString(sha.ComputeHash(file)).Replace("-","");
    if(!string.Equals(actual,package.Hash,StringComparison.OrdinalIgnoreCase))throw new IOException("Hash invalido. Instalacao bloqueada.");
   }
  }
 }
 static void CheckCancel(Func<bool> cancel){if(cancel!=null&&cancel())throw new OperationCanceledException();}
 static void Receive(string url,Stream output,long limit,Action<int,string> progress,Func<bool> cancel){
  CheckCancel(cancel);ServicePointManager.SecurityProtocol=SecurityProtocolType.Tls12;
  var request=(HttpWebRequest)WebRequest.Create(url);request.UserAgent="TarginoLauncher-Bootstrap";request.Timeout=20000;request.ReadWriteTimeout=30000;
  request.CachePolicy=new System.Net.Cache.RequestCachePolicy(System.Net.Cache.RequestCacheLevel.NoCacheNoStore);
  var timer=Stopwatch.StartNew();
  using(var response=(HttpWebResponse)request.GetResponse()){
   string host=response.ResponseUri.Host;
   if(response.ResponseUri.Scheme!="https"||(host!="api.github.com"&&host!="github.com"&&host!="release-assets.githubusercontent.com"&&host!="objects.githubusercontent.com"))throw new IOException("Redirecionamento nao autorizado.");
   if(response.ContentLength>limit)throw new IOException("Arquivo maior que o permitido.");
   using(var input=response.GetResponseStream()){
    byte[] buffer=new byte[65536];long total=0;int count;
    while((count=input.Read(buffer,0,buffer.Length))>0){
     CheckCancel(cancel);total+=count;if(total>limit||timer.Elapsed.TotalMinutes>15)throw new IOException("Limite de download excedido.");
     output.Write(buffer,0,count);if(progress!=null)progress((int)Math.Min(99,total*100/limit),"Baixando instalador... "+(total/1048576.0).ToString("0.0")+" MB");
    }
   }
  }
  CheckCancel(cancel);
 }
 static string ReceiveJson(string url,int limit,Func<bool> cancel){using(var output=new MemoryStream()){Receive(url,output,limit,null,cancel);return Encoding.UTF8.GetString(output.ToArray()).TrimStart('\uFEFF');}}
 public static StableBootstrapPackage ResolveLatest(Func<bool> cancel){
  string json=ReceiveJson(Latest,1048576,cancel),version=ReleaseVersion(json);
  var release=Json(json);object raw;if(!release.TryGetValue("assets",out raw)||!(raw is object[]))throw new IOException("Assets da release ausentes.");
  var assets=(object[])raw;string manifestUrl=Repository+"/releases/download/v"+version+"/update.json";int matches=0;
  foreach(var asset in assets){var item=asset as Dictionary<string,object>;if(item!=null&&Text(item,"name")=="update.json"&&Text(item,"browser_download_url")==manifestUrl)matches++;}
  if(matches!=1)throw new IOException("Manifesto oficial ausente ou duplicado.");
  var package=ReadManifest(ReceiveJson(manifestUrl,65536,cancel));if(package.Version!=version)throw new IOException("Versao difere da release.");matches=0;
  foreach(var asset in assets){var item=asset as Dictionary<string,object>;if(item!=null&&Text(item,"name")==package.FileName&&Text(item,"browser_download_url")==package.Url&&Number(item,"size")==package.Size)matches++;}
  if(matches!=1)throw new IOException("Instalador assinado ausente da release.");return package;
 }
 public static void Download(StableBootstrapPackage package,string destination,Action<int,string> progress,Func<bool> cancel){
  ValidateUrl(package.Url,package.Version,package.FileName);
  using(var output=new FileStream(destination,FileMode.CreateNew,FileAccess.Write,FileShare.None)){Receive(package.Url,output,package.Size,progress,cancel);}
  CheckCancel(cancel);ValidatePackage(destination,package);
 }
}

class StableBootstrap : Form {
 readonly BackgroundWorker worker=new BackgroundWorker{WorkerReportsProgress=true,WorkerSupportsCancellation=true};
 readonly Label status=new Label();readonly ProgressBar progress=new ProgressBar();readonly Button start=new Button();
 bool closeRequested;string packagePath;
 StableBootstrap(){
  Text="TarginoLauncher - Instalador online";ClientSize=new Size(620,305);StartPosition=FormStartPosition.CenterScreen;FormBorderStyle=FormBorderStyle.FixedDialog;MaximizeBox=false;
  BackColor=Color.FromArgb(15,25,33);ForeColor=Color.White;Font=new Font("Segoe UI",10);Icon=Icon.ExtractAssociatedIcon(Application.ExecutablePath);
  using(var stream=Assembly.GetExecutingAssembly().GetManifestResourceStream("brand.ico"))using(var logo=new Icon(stream,new Size(64,64))){Controls.Add(new PictureBox{Image=logo.ToBitmap(),Left=22,Top=20,Width=64,Height=64,SizeMode=PictureBoxSizeMode.Zoom});}
  Controls.Add(new Label{Text="TarginoLauncher",Font=new Font("Segoe UI",22,FontStyle.Bold),Left=100,Top=23,Width=490,Height=40});
  Controls.Add(new Label{Text="Recompilados by Central Arquivista",Left=102,Top=66,Width=480,Height=24,ForeColor=Color.LightGray});
  status.SetBounds(24,110,570,65);status.Text="Baixa a ultima versao estavel e abre o instalador completo.\r\nSomente o launcher: nao inclui jogos nem a base original.";
  progress.SetBounds(24,183,570,18);start.SetBounds(365,229,229,42);start.Text="Baixar e instalar";start.BackColor=Color.FromArgb(180,250,106);start.ForeColor=Color.FromArgb(19,32,10);start.FlatStyle=FlatStyle.Flat;
  Controls.AddRange(new Control[]{status,progress,start});
  start.Click+=(s,e)=>{if(worker.IsBusy){worker.CancelAsync();start.Enabled=false;status.Text="Cancelando... aguarde o encerramento da conexao.";}else{closeRequested=false;progress.Value=0;progress.Style=ProgressBarStyle.Marquee;status.Text="Consultando a ultima versao estavel...";start.Text="Cancelar";worker.RunWorkerAsync();}};
  worker.DoWork+=(s,e)=>{
   try{
    Func<bool> cancel=()=>worker.CancellationPending;
    var package=StableBootstrapSecurity.ResolveLatest(cancel);worker.ReportProgress(0,"Versao "+package.Version+" encontrada. Preparando download...");
    string folder=Path.Combine(Path.GetTempPath(),"TarginoLauncher-Bootstrap-"+Guid.NewGuid().ToString("N"));Directory.CreateDirectory(folder);packagePath=Path.Combine(folder,package.FileName);
    StableBootstrapSecurity.Download(package,packagePath,(percent,message)=>worker.ReportProgress(percent,message),cancel);
    if(worker.CancellationPending){e.Cancel=true;return;}e.Result=packagePath;
   }catch(OperationCanceledException){e.Cancel=true;}
  };
  worker.ProgressChanged+=(s,e)=>{progress.Style=ProgressBarStyle.Continuous;progress.Value=Math.Max(0,Math.Min(100,e.ProgressPercentage));status.Text=(string)e.UserState;};
  worker.RunWorkerCompleted+=(s,e)=>{
   start.Enabled=true;start.Text="Tentar novamente";progress.Style=ProgressBarStyle.Continuous;
   if(closeRequested||e.Cancelled){status.Text="Cancelado. Nenhum instalador foi executado.";if(closeRequested)Close();return;}
   if(e.Error!=null){status.Text="Nao foi possivel continuar: "+e.Error.Message;return;}
   try{progress.Value=100;status.Text="Pacote assinado e validado. Abrindo instalador...";using(var process=Process.Start(new ProcessStartInfo((string)e.Result){UseShellExecute=true})){if(process==null)throw new IOException("O instalador nao abriu.");}Close();}
   catch(Exception ex){status.Text="Nao foi possivel abrir o instalador: "+ex.Message;}
  };
  FormClosing+=(s,e)=>{if(worker.IsBusy){closeRequested=true;worker.CancelAsync();start.Enabled=false;status.Text="Cancelando... aguarde o encerramento da conexao.";e.Cancel=true;}};
 }
 [STAThread]static int Main(string[] args){
  if(args.Length==3&&args[0]=="--verify-package"){try{var package=StableBootstrapSecurity.ReadManifest(File.ReadAllText(args[1]));StableBootstrapSecurity.ValidatePackage(args[2],package);return 0;}catch{return 1;}}
  Application.EnableVisualStyles();Application.SetCompatibleTextRenderingDefault(false);Application.Run(new StableBootstrap());return 0;
 }
}
