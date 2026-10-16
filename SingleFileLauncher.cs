using System;
using System.Diagnostics;
using System.IO;
using System.IO.Compression;
using System.Linq;
using System.Reflection;
using System.Windows.Forms;

internal static class Program
{
    [STAThread]
    private static void Main()
    {
        try
        {
            var appDir = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "DeviceSwitchPortable");
            if (Directory.Exists(appDir))
            {
                Directory.Delete(appDir, true);
            }
            Directory.CreateDirectory(appDir);

            var assembly = Assembly.GetExecutingAssembly();
            var resourceName = assembly.GetManifestResourceNames()
                .FirstOrDefault(name => name.EndsWith("payload.zip", StringComparison.OrdinalIgnoreCase));

            if (resourceName == null)
            {
                throw new FileNotFoundException("Embedded payload was not found.");
            }

            var zipPath = Path.Combine(appDir, "payload.zip");
            using (var resourceStream = assembly.GetManifestResourceStream(resourceName))
            using (var fileStream = File.Create(zipPath))
            {
                if (resourceStream == null)
                {
                    throw new FileNotFoundException("Embedded payload stream was not found.");
                }
                resourceStream.CopyTo(fileStream);
            }

            ZipFile.ExtractToDirectory(zipPath, appDir);
            File.Delete(zipPath);

            var targetExe = Path.Combine(appDir, "DeviceSwitch.exe");
            if (!File.Exists(targetExe))
            {
                throw new FileNotFoundException("Extracted application was not found.", targetExe);
            }

            Process.Start(new ProcessStartInfo
            {
                FileName = targetExe,
                WorkingDirectory = appDir,
                UseShellExecute = true
            });
        }
        catch (Exception ex)
        {
            MessageBox.Show(ex.Message, "DeviceSwitch Portable", MessageBoxButtons.OK, MessageBoxIcon.Error);
        }
    }
}
