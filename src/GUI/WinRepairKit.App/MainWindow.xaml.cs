using System.Windows;
using WinRepairKit.App.ViewModels;

namespace WinRepairKit.App;

public partial class MainWindow : Window
{
    public MainWindow()
    {
        InitializeComponent();
        Loaded += async (_, _) =>
        {
            if (DataContext is MainViewModel vm)
            {
                await vm.InitializeAsync();
            }
        };
    }
}
