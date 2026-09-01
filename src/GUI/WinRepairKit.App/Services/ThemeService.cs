using System;
using System.Linq;
using System.Windows;

namespace WinRepairKit.App.Services;

public enum AppTheme
{
    Fluent,
    Cyberpunk2077
}

public static class ThemeService
{
    private static AppTheme _currentTheme = AppTheme.Fluent;
    public static AppTheme CurrentTheme => _currentTheme;

    public static void ApplyTheme(AppTheme theme)
    {
        _currentTheme = theme;
        var uriString = theme switch
        {
            AppTheme.Cyberpunk2077 => "pack://application:,,,/WinRepairKit;component/Styles/Themes/ThemeCyberpunk.xaml",
            _ => "pack://application:,,,/WinRepairKit;component/Styles/Themes/ThemeFluent.xaml"
        };

        try
        {
            var app = Application.Current;
            if (app == null) return;

            app.Dispatcher.Invoke(() =>
            {
                var newDict = new ResourceDictionary { Source = new Uri(uriString, UriKind.Absolute) };
                
                // Find existing theme dictionary
                var existingTheme = app.Resources.MergedDictionaries.FirstOrDefault(d =>
                    d.Source != null && d.Source.OriginalString.Contains("Theme"));

                if (existingTheme != null)
                {
                    var idx = app.Resources.MergedDictionaries.IndexOf(existingTheme);
                    app.Resources.MergedDictionaries[idx] = newDict;
                }
                else
                {
                    app.Resources.MergedDictionaries.Insert(0, newDict);
                }

                // Also update any brush keys directly on App resources for immediate fallback
                foreach (var key in newDict.Keys)
                {
                    app.Resources[key] = newDict[key];
                }
            });
        }
        catch (Exception ex)
        {
            System.Diagnostics.Debug.WriteLine($"[ThemeService] Error applying theme: {ex.Message}");
        }
    }
}
