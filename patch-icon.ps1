param([string]$SrcDir, [string]$Ico)
$ErrorActionPreference = 'Stop'
Add-Type -TypeDefinition @'
using System;
using System.IO;
using System.Collections.Generic;
using System.Runtime.InteropServices;
public static class IcoPatch {
  delegate bool EnumNameProc(IntPtr m, IntPtr type, IntPtr name, IntPtr l);
  delegate bool EnumLangProc(IntPtr m, IntPtr type, IntPtr name, ushort lang, IntPtr l);
  [DllImport("kernel32.dll", CharSet=CharSet.Unicode)] static extern IntPtr LoadLibraryEx(string f, IntPtr h, uint fl);
  [DllImport("kernel32.dll")] static extern bool FreeLibrary(IntPtr m);
  [DllImport("kernel32.dll")] static extern bool EnumResourceNames(IntPtr m, IntPtr type, EnumNameProc p, IntPtr l);
  [DllImport("kernel32.dll")] static extern bool EnumResourceLanguages(IntPtr m, IntPtr type, IntPtr name, EnumLangProc p, IntPtr l);
  [DllImport("kernel32.dll", CharSet=CharSet.Unicode)] static extern IntPtr BeginUpdateResource(string f, bool del);
  [DllImport("kernel32.dll")] static extern bool UpdateResource(IntPtr h, IntPtr type, IntPtr name, ushort lang, byte[] data, uint cb);
  [DllImport("kernel32.dll")] static extern bool EndUpdateResource(IntPtr h, bool discard);

  public static string Patch(string exe, string ico) {
    var groups = new List<KeyValuePair<IntPtr, ushort>>();
    IntPtr m = LoadLibraryEx(exe, IntPtr.Zero, 0x2);
    if (m == IntPtr.Zero) throw new Exception("load failed");
    EnumResourceNames(m, (IntPtr)14, (mm, t, n, l) => {
      EnumResourceLanguages(mm, t, n, (a, b, c, lang, d) => { groups.Add(new KeyValuePair<IntPtr, ushort>(c, lang)); return true; }, IntPtr.Zero);
      return true; }, IntPtr.Zero);
    FreeLibrary(m);
    if (groups.Count == 0) throw new Exception("no icon groups");

    byte[] dat = File.ReadAllBytes(ico);
    int count = BitConverter.ToUInt16(dat, 4);
    var grp = new MemoryStream(); var w = new BinaryWriter(grp);
    w.Write((ushort)0); w.Write((ushort)1); w.Write((ushort)count);
    IntPtr h = BeginUpdateResource(exe, false);
    if (h == IntPtr.Zero) throw new Exception("begin failed");
    for (int i = 0; i < count; i++) {
      int o = 6 + i * 16;
      uint size = BitConverter.ToUInt32(dat, o + 8), off = BitConverter.ToUInt32(dat, o + 12);
      byte[] img = new byte[size]; Array.Copy(dat, off, img, 0, size);
      ushort id = (ushort)(2000 + i);
      if (!UpdateResource(h, (IntPtr)3, (IntPtr)id, 1033, img, size)) throw new Exception("icon update failed");
      w.Write(dat[o]); w.Write(dat[o + 1]); w.Write(dat[o + 2]); w.Write(dat[o + 3]);
      w.Write(BitConverter.ToUInt16(dat, o + 4)); w.Write(BitConverter.ToUInt16(dat, o + 6));
      w.Write(size); w.Write(id);
    }
    byte[] g = grp.ToArray();
    foreach (var kv in groups)
      if (!UpdateResource(h, (IntPtr)14, kv.Key, kv.Value, g, (uint)g.Length)) throw new Exception("group update failed");
    if (!EndUpdateResource(h, false)) throw new Exception("end failed");
    return groups.Count + " group(s) replaced";
  }
}
'@
$exe = Join-Path $SrcDir 'WindowsTerminal.exe'
Copy-Item $exe (Join-Path $SrcDir 'WindowsTerminal.exe.orig') -ErrorAction SilentlyContinue
[IcoPatch]::Patch($exe, $Ico)
