using System;
using System.Diagnostics;
using System.IO;
using System.Runtime.Serialization;
using System.Runtime.Serialization.Json;
using System.Text;
using System.Windows.Forms;
[DataContract] public class CurrentRelease {
    [DataMember] public string directory;
}
public static class Launcher {
    static string Quote(string s) {
        StringBuilder b = new StringBuilder("\""); int slashes = 0;
        foreach (char c in s) {
            if (c == '\\') { slashes++; continue; }
            if (c == '"') { b.Append('\\', slashes * 2 + 1); b.Append(c); }
            else { b.Append('\\', slashes); b.Append(c); }
            slashes = 0;
        }
        b.Append('\\', slashes * 2); b.Append('"'); return b.ToString();
    }
    static CurrentRelease Read(string p) {
        try { using (MemoryStream f = new MemoryStream(Encoding.UTF8.GetBytes(File.ReadAllText(p)))) return (CurrentRelease)new DataContractJsonSerializer(typeof(CurrentRelease)).ReadObject(f); }
        catch { return null; }
    }
    static string Resolve(string root, string pointer) {
        CurrentRelease r = Read(Path.Combine(root, pointer));
        if (r == null || String.IsNullOrEmpty(r.directory)) return null;
        try {
            string dir = Path.GetFullPath(Path.Combine(root, r.directory));
            if (!dir.StartsWith(Path.Combine(root, "versions") + Path.DirectorySeparatorChar, StringComparison.OrdinalIgnoreCase)) return null;
            if (!File.Exists(Path.Combine(dir, "ChibiRTS.exe")) || !File.Exists(Path.Combine(dir, "ChibiRTS.pck"))) return null;
            return dir;
        } catch { return null; }
    }
    [STAThread] public static int Main(string[] args) {
        string root = AppDomain.CurrentDomain.BaseDirectory;
        try {
            string dir = Resolve(root, "current.json") ?? Resolve(root, "current.json.bak");
            if (dir == null) throw new IOException("找不到完整的已发布版本。");
            string exe = Path.Combine(dir, "ChibiRTS.exe");
            StringBuilder arguments = new StringBuilder();
            foreach (string a in args) { if (arguments.Length > 0) arguments.Append(' '); arguments.Append(Quote(a)); }
            if (File.Exists(Path.Combine(dir, "portable.txt")) && !Array.Exists(args, a => a.StartsWith("--portable-root="))) {
                if (Array.IndexOf(args, "--") < 0) arguments.Append(" --");
                arguments.Append(' '); arguments.Append(Quote("--portable-root=" + Path.Combine(root, "userdata")));
            }
            Process p = Process.Start(new ProcessStartInfo(exe, arguments.ToString()) { WorkingDirectory = dir, UseShellExecute = false });
            p.WaitForExit(); return p.ExitCode;
        } catch (Exception e) {
            File.WriteAllText(Path.Combine(root, "launcher-error.log"), e.ToString());
            if (Array.IndexOf(args, "--headless") < 0) MessageBox.Show(e.Message, "赤壁之战");
            return 1;
        }
    }
}
