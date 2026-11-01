$ErrorActionPreference = 'Stop'
$ico = Join-Path $PSScriptRoot 'icon.ico'
$log = Join-Path $PSScriptRoot 'launch.log'

Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
using System.Text;
public static class WinTag {
  [StructLayout(LayoutKind.Sequential, Pack = 4)] public struct PROPERTYKEY { public Guid fmtid; public uint pid; }
  [StructLayout(LayoutKind.Sequential)] public struct PROPVARIANT { public ushort vt, r1, r2, r3; public IntPtr p; public IntPtr p2; }
  [ComImport, Guid("886D8EEB-8CF2-4446-8D02-CDBA1DBDCF99"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
  public interface IPropertyStore {
    int GetCount(out uint c); int GetAt(uint i, out PROPERTYKEY k);
    int GetValue(ref PROPERTYKEY k, out PROPVARIANT v);
    int SetValue(ref PROPERTYKEY k, ref PROPVARIANT v); int Commit();
  }
  public delegate bool EnumProc(IntPtr h, IntPtr l);
  [DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc p, IntPtr l);
  [DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern int GetClassName(IntPtr h, StringBuilder s, int n);
  [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
  [DllImport("user32.dll")] public static extern IntPtr SendMessage(IntPtr h, uint m, IntPtr w, IntPtr l);
  [DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern IntPtr LoadImage(IntPtr i, string f, uint t, int cx, int cy, uint fl);
  [DllImport("shell32.dll")] public static extern int SHGetPropertyStoreForWindow(IntPtr h, ref Guid riid, out IPropertyStore ps);

  public static IntPtr[] FindTerminals() {
    var list = new System.Collections.Generic.List<IntPtr>();
    EnumWindows((h, l) => {
      var sb = new StringBuilder(256); GetClassName(h, sb, 256);
      if (sb.ToString() == "CASCADIA_HOSTING_WINDOW_CLASS" && IsWindowVisible(h)) list.Add(h);
      return true; }, IntPtr.Zero);
    return list.ToArray();
  }
  public static void SetIcons(IntPtr h, string path) {
    IntPtr big = LoadImage(IntPtr.Zero, path, 1, 32, 32, 0x10);
    IntPtr small = LoadImage(IntPtr.Zero, path, 1, 16, 16, 0x10);
    SendMessage(h, 0x80, (IntPtr)1, big);
    SendMessage(h, 0x80, (IntPtr)0, small);
  }
  public static void SetAppId(IntPtr h, string id) {
    Guid iid = new Guid("886D8EEB-8CF2-4446-8D02-CDBA1DBDCF99");
    IPropertyStore ps; Marshal.ThrowExceptionForHR(SHGetPropertyStoreForWindow(h, ref iid, out ps));
    var key = new PROPERTYKEY { fmtid = new Guid("9F4C2855-9F79-4B39-A8D0-E1D42DE1D5F3"), pid = 5 };
    var v = new PROPVARIANT { vt = 31, p = Marshal.StringToCoTaskMemUni(id) };
    Marshal.ThrowExceptionForHR(ps.SetValue(ref key, ref v)); ps.Commit();
  }
}
'@

$before = @([WinTag]::FindTerminals())
$wt = (Get-ChildItem (Join-Path $PSScriptRoot 'wt-portable') -Recurse -Filter WindowsTerminal.exe | select -First 1).FullName
Start-Process $wt -ArgumentList '-w', 'new', 'new-tab', '-p', 'Claude'

$hwnd = [IntPtr]::Zero
for ($i = 0; $i -lt 100 -and $hwnd -eq [IntPtr]::Zero; $i++) {
  Start-Sleep -Milliseconds 100
  $new = @([WinTag]::FindTerminals() | Where-Object { $before -notcontains $_ })
  if ($new.Count -gt 0) { $hwnd = $new[0] }
}
if ($hwnd -eq [IntPtr]::Zero) { 'window not found' | Out-File $log; exit 1 }

Start-Sleep -Milliseconds 500
$msg = 'ok'
try { [WinTag]::SetAppId($hwnd, 'ClaudeCodeTerminal.Custom') } catch { $msg = "appid failed: $($_.Exception.Message)" }
[WinTag]::SetIcons($hwnd, $ico)
$msg | Out-File $log
