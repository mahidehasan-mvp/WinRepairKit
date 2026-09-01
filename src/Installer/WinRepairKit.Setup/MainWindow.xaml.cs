using System.Windows;

namespace WinRepairKit.Setup;

public partial class MainWindow : Window
{
    public MainWindow()
    {
        InitializeComponent();
        DataContext = new SetupViewModel();
    }
}
