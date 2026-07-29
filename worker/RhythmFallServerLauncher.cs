using System;
using System.Diagnostics;
using System.IO;
using System.Runtime.InteropServices;
using System.Text;

internal static class RhythmFallServerLauncher
{
    private const int STD_OUTPUT_HANDLE = -11;
    private const uint ENABLE_VIRTUAL_TERMINAL_PROCESSING = 0x0004;

    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern IntPtr GetStdHandle(int nStdHandle);

    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern bool GetConsoleMode(IntPtr hConsoleHandle, out uint lpMode);

    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern bool SetConsoleMode(IntPtr hConsoleHandle, uint dwMode);

    private static void EnableAnsiColors()
    {
        try
        {
            IntPtr handle = GetStdHandle(STD_OUTPUT_HANDLE);
            uint mode;
            if (GetConsoleMode(handle, out mode))
            {
                SetConsoleMode(handle, mode | ENABLE_VIRTUAL_TERMINAL_PROCESSING);
            }
        }
        catch
        {
        }
    }

    private static int Main(string[] args)
    {
        Console.Title = "RhythmFall Generation Server";
        Console.OutputEncoding = Encoding.UTF8;
        EnableAnsiColors();

        string root = AppDomain.CurrentDomain.BaseDirectory.TrimEnd('\\', '/');
        string workerDir = Path.Combine(root, "worker");
        string serverDir = ResolveServerDir(root, workerDir);
        if (serverDir == null)
        {
            Console.Error.WriteLine("[RhythmFall] RhythmFallServer folder not found (need run.py).");
            Pause();
            return 1;
        }

        string port = Environment.GetEnvironmentVariable("RF_BIND_PORT");
        if (string.IsNullOrWhiteSpace(port))
        {
            port = "5000";
        }

        bool useWsl = UseWslMode(root);
        Console.WriteLine("[RhythmFall] Server: " + serverDir);
        Console.WriteLine("[RhythmFall] Mode: " + (useWsl ? "WSL" : "Windows Python"));
        Console.WriteLine("[RhythmFall] Close this window to stop the server.");
        Console.WriteLine();

        try
        {
            int exitCode = useWsl ? RunWslServer(serverDir, port) : RunNativeServer(serverDir, port);
            Console.WriteLine();
            Console.WriteLine("[RhythmFall] Server stopped (exit " + exitCode + ").");
            Pause();
            return exitCode;
        }
        catch (Exception ex)
        {
            Console.Error.WriteLine("[RhythmFall] " + ex.Message);
            Pause();
            return 4;
        }
    }

    private static bool UseWslMode(string root)
    {
        string flag = Environment.GetEnvironmentVariable("RFALL_USE_WSL");
        if (!string.IsNullOrWhiteSpace(flag))
        {
            flag = flag.Trim().ToLowerInvariant();
            if (flag == "0" || flag == "false" || flag == "no" || flag == "off")
            {
                return false;
            }
            return flag == "1" || flag == "true" || flag == "yes" || flag == "on";
        }

        string bat = Environment.GetEnvironmentVariable("RFALL_SERVER_BAT");
        if (!string.IsNullOrWhiteSpace(bat))
        {
            return bat.IndexOf("wsl", StringComparison.OrdinalIgnoreCase) >= 0;
        }

        string wslFlag = Path.Combine(root, "worker", "use_wsl.flag");
        if (File.Exists(wslFlag))
        {
            return true;
        }

        return false;
    }

    private static string ReadPathFile(string pathFile)
    {
        if (!File.Exists(pathFile))
        {
            return null;
        }
        string text = File.ReadAllText(pathFile, Encoding.UTF8).Trim();
        if (text.Length > 0 && text[0] == '\uFEFF')
        {
            text = text.Substring(1).Trim();
        }
        return text;
    }

    private static int RunNativeServer(string serverDir, string port)
    {
        string python = Environment.GetEnvironmentVariable("RFALL_PYTHON");
        if (string.IsNullOrWhiteSpace(python))
        {
            string venvPython = Path.Combine(serverDir, ".venv", "Scripts", "python.exe");
            if (File.Exists(venvPython))
            {
                python = venvPython;
            }
        }
        if (string.IsNullOrWhiteSpace(python))
        {
            string root = AppDomain.CurrentDomain.BaseDirectory.TrimEnd('\\', '/');
            string pathFile = Path.Combine(root, "worker", "windows_python.path");
            python = ReadPathFile(pathFile);
        }
        if (!string.IsNullOrWhiteSpace(python) && !File.Exists(python))
        {
            Console.Error.WriteLine("[RhythmFall] Python not found: " + python);
            python = null;
        }
        if (string.IsNullOrWhiteSpace(python))
        {
            python = "python";
        }

        Console.WriteLine("[RhythmFall] Python: " + python);
        Console.WriteLine("[RhythmFall] Loading ML stack (first start may take 30-60s)...");
        Console.Out.Flush();

        var psi = new ProcessStartInfo
        {
            FileName = python,
            Arguments = "-u run.py",
            WorkingDirectory = serverDir,
            UseShellExecute = false,
            RedirectStandardOutput = true,
            RedirectStandardError = true,
        };
        psi.EnvironmentVariables["RF_BIND_HOST"] = "127.0.0.1";
        psi.EnvironmentVariables["RF_BIND_PORT"] = port;
        psi.EnvironmentVariables["RF_FLASK_DEBUG"] = "0";
        psi.EnvironmentVariables["PYTHONUNBUFFERED"] = "1";
        psi.EnvironmentVariables["PYTHONIOENCODING"] = "utf-8";
        psi.EnvironmentVariables["TF_CPP_MIN_LOG_LEVEL"] = "2";
        psi.EnvironmentVariables["ORT_LOG_SEVERITY_LEVEL"] = "3";
        if (string.IsNullOrWhiteSpace(Environment.GetEnvironmentVariable("RFALL_GPU")))
        {
            psi.EnvironmentVariables["RFALL_GPU"] = "auto";
        }
        else
        {
            psi.EnvironmentVariables["RFALL_GPU"] = Environment.GetEnvironmentVariable("RFALL_GPU");
        }
        string chartVariant = Environment.GetEnvironmentVariable("RFALL_CHART_VARIANT");
        if (!string.IsNullOrWhiteSpace(chartVariant))
        {
            psi.EnvironmentVariables["RFALL_CHART_VARIANT"] = chartVariant.Trim();
        }

        using (var proc = Process.Start(psi))
        {
            if (proc == null)
            {
                throw new InvalidOperationException("Failed to start python. Install deps: pip install -r requirements.txt");
            }
            Console.CancelKeyPress += delegate(object sender, ConsoleCancelEventArgs e)
            {
                e.Cancel = true;
                KillProcessTree(proc);
                Environment.Exit(130);
            };
            proc.OutputDataReceived += delegate(object sender, DataReceivedEventArgs e)
            {
                if (!string.IsNullOrEmpty(e.Data))
                {
                    Console.WriteLine(e.Data);
                }
            };
            proc.ErrorDataReceived += delegate(object sender, DataReceivedEventArgs e)
            {
                if (!string.IsNullOrEmpty(e.Data))
                {
                    Console.Error.WriteLine(e.Data);
                }
            };
            proc.BeginOutputReadLine();
            proc.BeginErrorReadLine();
            proc.WaitForExit();
            return proc.ExitCode;
        }
    }

    private static string GetWslDistro()
    {
        string distro = Environment.GetEnvironmentVariable("RFALL_WSL_DISTRO");
        if (!string.IsNullOrWhiteSpace(distro))
        {
            return distro.Trim();
        }
        return "Ubuntu";
    }

    private static int RunWslServer(string serverDir, string port)
    {
        string distro = GetWslDistro();
        string wslServer = WslPath(serverDir, distro);
        if (string.IsNullOrWhiteSpace(wslServer))
        {
            throw new InvalidOperationException("Could not map path to WSL. Try without RFALL_USE_WSL.");
        }

        Console.WriteLine("[RhythmFall] WSL distro: " + distro);
        Console.WriteLine("[RhythmFall] WSL path: " + wslServer);

        string bash = string.Format(
            "cd '{0}' && export RF_BIND_HOST=0.0.0.0 && export RF_BIND_PORT={1} && export RF_FLASK_DEBUG=0 && export PYTHONUNBUFFERED=1 && if [ -f ~/rhythmfall-venv/bin/activate ]; then . ~/rhythmfall-venv/bin/activate; fi && python3 -u run.py",
            wslServer,
            port
        );

        var psi = new ProcessStartInfo
        {
            FileName = "wsl.exe",
            Arguments = "-d " + distro + " -e bash -lc \"" + bash.Replace("\"", "\\\"") + "\"",
            UseShellExecute = false,
        };

        using (var proc = Process.Start(psi))
        {
            if (proc == null)
            {
                throw new InvalidOperationException("Failed to start wsl.exe");
            }
            proc.WaitForExit();
            return proc.ExitCode;
        }
    }

    private static string ResolveServerDir(string root, string workerDir)
    {
        string envRoot = Environment.GetEnvironmentVariable("RFALL_SERVER_ROOT");
        if (!string.IsNullOrWhiteSpace(envRoot) && File.Exists(Path.Combine(envRoot, "run.py")))
        {
            return Path.GetFullPath(envRoot);
        }

        string pathFile = Path.Combine(workerDir, "server_root.path");
        string custom = ReadPathFile(pathFile);
        if (!string.IsNullOrWhiteSpace(custom) && File.Exists(Path.Combine(custom, "run.py")))
        {
            return Path.GetFullPath(custom);
        }

        string sibling = Path.Combine(root, "RhythmFallServer");
        if (File.Exists(Path.Combine(sibling, "run.py")))
        {
            return sibling;
        }

        return null;
    }

    private static string WslPath(string winPath)
    {
        return WslPath(winPath, GetWslDistro());
    }

    private static string NormalizeWslPath(string path)
    {
        if (string.IsNullOrWhiteSpace(path))
        {
            return path;
        }
        // docker-desktop wslpath may return /mnt/host/d/... which fails in Ubuntu.
        if (path.StartsWith("/mnt/host/", StringComparison.OrdinalIgnoreCase) && path.Length >= 12)
        {
            char drive = char.ToLowerInvariant(path[10]);
            if (drive >= 'a' && drive <= 'z' && path[11] == '/')
            {
                return "/mnt/" + drive + path.Substring(11);
            }
        }
        return path;
    }

    private static string WslPath(string winPath, string distro)
    {
        winPath = Path.GetFullPath(winPath);
        string mapped = TryWslPath(winPath, distro);
        if (!string.IsNullOrWhiteSpace(mapped))
        {
            return NormalizeWslPath(mapped);
        }
        return WinPathToWslMount(winPath);
    }

    private static string TryWslPath(string winPath, string distro)
    {
        var psi = new ProcessStartInfo
        {
            FileName = "wsl.exe",
            Arguments = "-d " + distro + " -e wslpath -u \"" + winPath + "\"",
            RedirectStandardOutput = true,
            RedirectStandardError = true,
            UseShellExecute = false,
            CreateNoWindow = true,
        };

        try
        {
            using (var proc = Process.Start(psi))
            {
                if (proc == null)
                {
                    return null;
                }
                string output = proc.StandardOutput.ReadToEnd();
                proc.StandardError.ReadToEnd();
                proc.WaitForExit();
                output = output.Trim();
                if (proc.ExitCode != 0 || output == "")
                {
                    return null;
                }
                return output;
            }
        }
        catch
        {
            return null;
        }
    }

    private static string WinPathToWslMount(string winPath)
    {
        if (winPath.Length >= 2 && winPath[1] == ':')
        {
            char drive = char.ToLowerInvariant(winPath[0]);
            string tail = winPath.Substring(2).Replace('\\', '/');
            if (!tail.StartsWith("/"))
            {
                tail = "/" + tail.TrimStart('/');
            }
            return "/mnt/" + drive + tail;
        }
        return winPath.Replace('\\', '/');
    }

    private static void KillProcessTree(Process proc)
    {
        if (proc == null)
        {
            return;
        }
        try
        {
            if (!proc.HasExited)
            {
                if (Environment.OSVersion.Platform == PlatformID.Win32NT)
                {
                    var kill = new ProcessStartInfo
                    {
                        FileName = "taskkill",
                        Arguments = "/T /F /PID " + proc.Id,
                        CreateNoWindow = true,
                        UseShellExecute = false,
                    };
                    using (var killer = Process.Start(kill))
                    {
                        if (killer != null)
                        {
                            killer.WaitForExit(8000);
                        }
                    }
                }
                else
                {
                    proc.Kill();
                }
            }
        }
        catch
        {
            try
            {
                if (!proc.HasExited)
                {
                    proc.Kill();
                }
            }
            catch
            {
            }
        }
    }

    private static void Pause()
    {
        Console.WriteLine();
        Console.WriteLine("Press Enter to exit...");
        Console.ReadLine();
    }
}
