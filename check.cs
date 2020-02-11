using System;
using System.IO;

namespace test
{
    class main {
        public static void Main(String[] args) {
            String tempPath = Path.GetTempPath();
            String musicPath = Environment.GetFolderPath(Environment.SpecialFolder.MyMusic);
            String desktopPath = Environment.GetFolderPath(Environment.SpecialFolder.DesktopDirectory);
            String appDataPath = Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData);

            Console.Out.WriteLine("tempPath: "+tempPath);
            Console.Out.WriteLine("musicPath: "+musicPath);
            Console.Out.WriteLine("desktopPath: "+desktopPath);
            Console.Out.WriteLine("appDataPath: "+appDataPath);
            
            DirectoryInfo tempDir = new DirectoryInfo(tempPath + "\\AdvancedCombatTracker");
            DirectoryInfo folderMedia = new DirectoryInfo(musicPath);
            DirectoryInfo folderExports = new DirectoryInfo(desktopPath);
            DirectoryInfo appDataFolder = new DirectoryInfo(appDataPath + "\\Advanced Combat Tracker");

            Console.Out.WriteLine("tempDir: "+tempDir);
            Console.Out.WriteLine("folderMedia: "+folderMedia);
            Console.Out.WriteLine("folderExports: "+folderExports);
            Console.Out.WriteLine("appDataFolder: "+appDataFolder);
        }
    }
}