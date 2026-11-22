<#
.SYNOPSIS
  Extracts the icon embedded in an .exe and saves it as a multi-size .ico file.
#>
param(
  [Parameter(Mandatory)][string]$Exe,
  [Parameter(Mandatory)][string]$Out
)
$ErrorActionPreference = 'Stop'
Add-Type -TypeDefinition @'
using System;
using System.IO;
using System.Collections.Generic;
using System.Runtime.InteropServices;
public static class IcoExtract {
  delegate bool EnumNameProc(IntPtr m, IntPtr type, IntPtr name, IntPtr l);
  [DllImport("kernel32.dll", CharSet=CharSet.Unicode)] static extern IntPtr LoadLibraryEx(string f, IntPtr h, uint fl);
  [DllImport("kernel32.dll")] static extern bool FreeLibrary(IntPtr m);
  [DllImport("kernel32.dll")] static extern bool EnumResourceNames(IntPtr m, IntPtr type, EnumNameProc p, IntPtr l);
  [DllImport("kernel32.dll")] static extern IntPtr FindResource(IntPtr m, IntPtr name, IntPtr type);
  [DllImport("kernel32.dll")] static extern IntPtr LoadResource(IntPtr m, IntPtr res);
  [DllImport("kernel32.dll")] static extern IntPtr LockResource(IntPtr res);
  [DllImport("kernel32.dll")] static extern uint SizeofResource(IntPtr m, IntPtr res);

  static byte[] Get(IntPtr m, IntPtr type, IntPtr name) {
    IntPtr r = FindResource(m, name, type);
    if (r == IntPtr.Zero) throw new Exception("resource not found");
    uint sz = SizeofResource(m, r);
    byte[] b = new byte[sz];
    Marshal.Copy(LockResource(LoadResource(m, r)), b, 0, (int)sz);
    return b;
  }

  public static void Extract(string exe, string outPath) {
    IntPtr m = LoadLibraryEx(exe, IntPtr.Zero, 0x2);
    if (m == IntPtr.Zero) throw new Exception("could not load " + exe);
    try {
      IntPtr first = IntPtr.Zero;
      EnumResourceNames(m, (IntPtr)14, (mm, t, n, l) => { first = n; return false; }, IntPtr.Zero);
      if (first == IntPtr.Zero) throw new Exception("no icon in " + exe);
      byte[] grp = Get(m, (IntPtr)14, first);
      int count = BitConverter.ToUInt16(grp, 4);
      var imgs = new List<byte[]>();
      for (int i = 0; i < count; i++)
        imgs.Add(Get(m, (IntPtr)3, (IntPtr)BitConverter.ToUInt16(grp, 6 + i * 14 + 12)));
      var ms = new MemoryStream(); var w = new BinaryWriter(ms);
      w.Write((ushort)0); w.Write((ushort)1); w.Write((ushort)count);
      uint off = (uint)(6 + 16 * count);
      for (int i = 0; i < count; i++) {
        int o = 6 + i * 14;
        w.Write(grp[o]); w.Write(grp[o + 1]); w.Write(grp[o + 2]); w.Write(grp[o + 3]);
        w.Write(BitConverter.ToUInt16(grp, o + 4)); w.Write(BitConverter.ToUInt16(grp, o + 6));
        w.Write((uint)imgs[i].Length); w.Write(off);
        off += (uint)imgs[i].Length;
      }
      foreach (var im in imgs) w.Write(im);
      File.WriteAllBytes(outPath, ms.ToArray());
    } finally { FreeLibrary(m); }
  }
}
'@
[IcoExtract]::Extract($Exe, $Out)
