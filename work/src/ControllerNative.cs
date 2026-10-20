using System;
using System.Runtime.InteropServices;
namespace CentralInput {
 public sealed class PadState { public string Device=""; public string Kind=""; public string Direction=""; public uint Buttons; }
 public static class Native {
  [StructLayout(LayoutKind.Sequential)] struct Joy {public uint Size,Flags,X,Y,Z,R,U,V,Buttons,ButtonNumber,POV,Reserved1,Reserved2;}
  [StructLayout(LayoutKind.Sequential,CharSet=CharSet.Unicode)] struct Caps {
   public ushort Mid,Pid; [MarshalAs(UnmanagedType.ByValTStr,SizeConst=32)] public string Name;
   public uint Xmin,Xmax,Ymin,Ymax,Zmin,Zmax,Buttons,PeriodMin,PeriodMax,Rmin,Rmax,Umin,Umax,Vmin,Vmax,Capabilities,MaxAxes,Axes,MaxButtons;
   [MarshalAs(UnmanagedType.ByValTStr,SizeConst=32)] public string RegKey;
   [MarshalAs(UnmanagedType.ByValTStr,SizeConst=260)] public string OEM;
  }
  [StructLayout(LayoutKind.Sequential)] struct Gamepad {public ushort Buttons;public byte LT,RT;public short LX,LY,RX,RY;}
  [StructLayout(LayoutKind.Sequential)] struct XState {public uint Packet;public Gamepad Pad;}
  [DllImport("winmm.dll")] static extern uint joyGetPosEx(uint id,ref Joy value);
  [DllImport("winmm.dll",CharSet=CharSet.Unicode)] static extern uint joyGetDevCapsW(UIntPtr id,out Caps caps,uint size);
  [DllImport("xinput1_4.dll",EntryPoint="XInputGetState")] static extern uint X4(uint id,out XState state);
  [DllImport("xinput9_1_0.dll",EntryPoint="XInputGetState")] static extern uint X9(uint id,out XState state);
  [DllImport("user32.dll")] static extern IntPtr GetForegroundWindow();
  [DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr window,out uint pid);
  public static bool IsForeground(uint pid){uint owner;GetWindowThreadProcessId(GetForegroundWindow(),out owner);return owner==pid;}
  static int device=-1; static bool xbox; static Caps caps; static DateTime nextProbe=DateTime.MinValue;
  static bool TryX(uint id,out XState state){try{return X4(id,out state)==0;}catch(DllNotFoundException){try{return X9(id,out state)==0;}catch(DllNotFoundException){state=new XState();return false;}}}
  public static PadState Poll(){
   if(device<0){
    if(DateTime.UtcNow<nextProbe)return new PadState();nextProbe=DateTime.UtcNow.AddSeconds(1);
    XState x;for(uint i=0;i<4;i++)if(TryX(i,out x)){device=(int)i;xbox=true;break;}
    if(device<0)for(uint i=0;i<16;i++){var j=new Joy{Size=(uint)Marshal.SizeOf(typeof(Joy)),Flags=255};if(joyGetPosEx(i,ref j)==0&&joyGetDevCapsW(new UIntPtr(i),out caps,(uint)Marshal.SizeOf(typeof(Caps)))==0){device=(int)i;xbox=false;break;}}
    if(device<0)return new PadState();
   }
   if(xbox){XState s;if(!TryX((uint)device,out s)){device=-1;return new PadState();}
    string d="";if((s.Pad.Buttons&4)!=0||s.Pad.LX<-16000)d="Left";else if((s.Pad.Buttons&8)!=0||s.Pad.LX>16000)d="Right";else if((s.Pad.Buttons&1)!=0||s.Pad.LY>16000)d="Up";else if((s.Pad.Buttons&2)!=0||s.Pad.LY<-16000)d="Down";
    return new PadState{Device="Xbox / XInput "+(device+1),Kind="XInput",Direction=d,Buttons=s.Pad.Buttons};
   }
   var joy=new Joy{Size=(uint)Marshal.SizeOf(typeof(Joy)),Flags=255};if(joyGetPosEx((uint)device,ref joy)!=0){device=-1;return new PadState();}
   string dir="";double nx=caps.Xmax>caps.Xmin?((double)joy.X-caps.Xmin)/(caps.Xmax-caps.Xmin):0.5;double ny=caps.Ymax>caps.Ymin?((double)joy.Y-caps.Ymin)/(caps.Ymax-caps.Ymin):0.5;
   if(nx<0.25)dir="Left";else if(nx>0.75)dir="Right";else if(ny<0.25)dir="Up";else if(ny>0.75)dir="Down";
   if((caps.Capabilities&16)!=0 && joy.POV!=65535 && joy.POV!=UInt32.MaxValue){if(joy.POV>=31500||joy.POV<4500)dir="Up";else if(joy.POV<13500)dir="Right";else if(joy.POV<22500)dir="Down";else dir="Left";}
   return new PadState{Device=caps.Name+" #"+(device+1),Kind="WinMM",Direction=dir,Buttons=joy.Buttons};
  }
 }
}
