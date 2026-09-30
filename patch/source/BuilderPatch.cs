using System;
using System.Collections.Generic;
using System.IO;
using System.Text.RegularExpressions;
using Microsoft.Win32;

internal static class BuilderPatch
{
	private const string InstallFolderName = "SN";
	private const string MarkerRelativePath = @"data\builder\builder";

	private static int Main(string[] args)
	{
		if (args.Length != 1)
		{
			return 2;
		}

		try
		{
			List<string> installs = FindSteamInstalls();
			if (args[0].Equals("probe", StringComparison.OrdinalIgnoreCase))
			{
				return installs.Count > 0 ? 0 : 3;
			}

			if (args[0].Equals("apply", StringComparison.OrdinalIgnoreCase))
			{
				if (installs.Count == 0)
				{
					return 3;
				}

				foreach (string install in installs)
				{
					string marker = Path.Combine(install, MarkerRelativePath);
					Directory.CreateDirectory(Path.GetDirectoryName(marker));
					File.WriteAllBytes(marker, new byte[0]);
				}

				return 0;
			}

			if (args[0].Equals("remove", StringComparison.OrdinalIgnoreCase))
			{
				foreach (string install in installs)
				{
					string marker = Path.Combine(install, MarkerRelativePath);
					if (File.Exists(marker))
					{
						File.Delete(marker);
					}
				}

				return 0;
			}

			return 2;
		}
		catch
		{
			return 1;
		}
	}

	private static List<string> FindSteamInstalls()
	{
		HashSet<string> steamRoots = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
		AddRegistryRoot(steamRoots, Registry.CurrentUser, @"Software\Valve\Steam", "SteamPath");
		AddRegistryRoot(steamRoots, Registry.CurrentUser, @"Software\Valve\Steam", "InstallPath");

		AddMachineRegistryRoot(steamRoots, RegistryView.Registry32);
		AddMachineRegistryRoot(steamRoots, RegistryView.Registry64);

		HashSet<string> libraries = new HashSet<string>(steamRoots, StringComparer.OrdinalIgnoreCase);
		foreach (string steamRoot in steamRoots)
		{
			string vdfPath = Path.Combine(steamRoot, @"steamapps\libraryfolders.vdf");
			if (!File.Exists(vdfPath))
			{
				continue;
			}

			string vdf = File.ReadAllText(vdfPath);
			MatchCollection matches = Regex.Matches(
				vdf,
				"\\\"path\\\"\\s+\\\"(?<path>(?:\\\\.|[^\\\"])*)\\\"",
				RegexOptions.IgnoreCase
			);
			foreach (Match match in matches)
			{
				AddPath(libraries, match.Groups["path"].Value.Replace(@"\\", @"\"));
			}
		}

		List<string> installs = new List<string>();
		foreach (string library in libraries)
		{
			string candidate = Path.Combine(library, "steamapps", "common", InstallFolderName);
			if (Directory.Exists(candidate))
			{
				installs.Add(Path.GetFullPath(candidate));
			}
		}

		return installs;
	}

	private static void AddMachineRegistryRoot(HashSet<string> roots, RegistryView view)
	{
		using (RegistryKey baseKey = RegistryKey.OpenBaseKey(RegistryHive.LocalMachine, view))
		{
			AddRegistryRoot(roots, baseKey, @"Software\Valve\Steam", "InstallPath");
		}
	}

	private static void AddRegistryRoot(
		HashSet<string> roots,
		RegistryKey baseKey,
		string subKey,
		string valueName)
	{
		using (RegistryKey key = baseKey.OpenSubKey(subKey))
		{
			if (key != null)
			{
				AddPath(roots, key.GetValue(valueName) as string);
			}
		}
	}

	private static void AddPath(HashSet<string> paths, string path)
	{
		if (!String.IsNullOrWhiteSpace(path))
		{
			paths.Add(Path.GetFullPath(Environment.ExpandEnvironmentVariables(path.Trim())));
		}
	}
}
