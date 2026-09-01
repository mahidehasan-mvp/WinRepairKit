using System;
using System.IO;
using System.Windows;
using System.Windows.Threading;

namespace WinRepairKit.App;

public partial class App : Application
{
    protected override void OnStartup(StartupEventArgs e)
    {
        base.OnStartup(e);

        AppDomain.CurrentDomain.UnhandledException += (s, args) =>
        {
            LogCrash(args.ExceptionObject as Exception);
        };

        DispatcherUnhandledException += (s, args) =>
        {
            LogCrash(args.Exception);
            args.Handled = true;
        };
    }

    private static void LogCrash(Exception? ex)
    {
        if (ex == null) return;
        try
        {
            var logPath = Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "crash.log");
            File.AppendAllText(logPath, $"[{DateTime.Now}] Crash: {ex}\n\n");
            MessageBox.Show($"WinRepairKit encountered an error:\n{ex.Message}", "WinRepairKit Error", MessageBoxButton.OK, MessageBoxImage.Error);
        }
        catch {}
    }
}
