# Active une entree d'un menu de Roblox Studio PAR SON NOM, sur un bureau Windows cache, via
# l'accessibilite (UI Automation). Remplace le clic a coordonnees fixes + fleches : la mise a jour
# de Studio du 2026-09-27 (14 h 45) a change l'echelle de la barre de menus ET l'ordre du menu
# Fichier (entrees ajoutees), et le geste positionnel ne publiait plus rien.
# Usage : powershell -File tools/studio_menu_uia.ps1 -Bureau AutowinTest_x -Menu Fichier -Entree "Publier sur Roblox"
# Sortie : une ligne « ok » ou le motif de l'echec ; code 0 si l'entree a ete activee.
param([Parameter(Mandatory = $true)][string]$Bureau,
      [string]$Menu = 'Fichier',
      [Parameter(Mandatory = $true)][string]$Entree)
Add-Type -AssemblyName UIAutomationClient, UIAutomationTypes
if (-not ('StudioMenuUia' -as [type])) {
Add-Type -ReferencedAssemblies UIAutomationClient, UIAutomationTypes, WindowsBase -TypeDefinition @"
using System; using System.Text; using System.Threading; using System.Collections.Generic; using System.Runtime.InteropServices; using System.Windows.Automation;
public static class StudioMenuUia {
  delegate bool EnumProc(IntPtr h, IntPtr l);
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] static extern IntPtr OpenDesktopW(string n, uint f, bool i, uint a);
  [DllImport("user32.dll")] static extern bool SetThreadDesktop(IntPtr h);
  [DllImport("user32.dll")] static extern bool EnumDesktopWindows(IntPtr d, EnumProc p, IntPtr l);
  [DllImport("user32.dll")] static extern bool IsWindowVisible(IntPtr h);
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] static extern int GetWindowTextW(IntPtr h, StringBuilder s, int n);
  static string Titre(IntPtr h) { var s = new StringBuilder(512); GetWindowTextW(h, s, 512); return s.ToString(); }
  static List<IntPtr> Fenetres(IntPtr d) {
    var l = new List<IntPtr>();
    EnumDesktopWindows(d, (h, x) => { if (IsWindowVisible(h)) l.Add(h); return true; }, IntPtr.Zero);
    return l;
  }
  static AutomationElement Item(AutomationElement racine, string nom) {
    var c = new AndCondition(new PropertyCondition(AutomationElement.ControlTypeProperty, ControlType.MenuItem),
                             new PropertyCondition(AutomationElement.NameProperty, nom));
    return racine.FindFirst(TreeScope.Descendants, c);
  }
  public static string Run(string bureau, string menu, string entree) {
    string res = "";
    var t = new Thread(() => {
      try {
        IntPtr d = OpenDesktopW(bureau, 0, false, 0x10000000);
        if (d == IntPtr.Zero) { res = "bureau introuvable : " + bureau; return; }
        SetThreadDesktop(d);
        IntPtr studio = IntPtr.Zero;
        foreach (var h in Fenetres(d)) if (Titre(h).EndsWith("- Roblox Studio")) { studio = h; break; }
        if (studio == IntPtr.Zero) { res = "fenetre de Studio introuvable"; return; }
        var m = Item(AutomationElement.FromHandle(studio), menu);
        if (m == null) { res = "menu introuvable : " + menu; return; }
        ((ExpandCollapsePattern)m.GetCurrentPattern(ExpandCollapsePattern.Pattern)).Expand();
        // Le menu deroule est une fenetre a part (« RobloxStudio ») : on y cherche l'entree EXACTE
        // (« Publier sur Roblox » et non « ... avec des notes » ni « ... comme »).
        AutomationElement cible = null;
        for (int essai = 0; essai < 20 && cible == null; essai++) {
          Thread.Sleep(250);
          foreach (var h in Fenetres(d)) {
            if (h == studio) continue;
            cible = Item(AutomationElement.FromHandle(h), entree);
            if (cible != null) break;
          }
        }
        if (cible == null) { res = "entree introuvable dans le menu " + menu + " : " + entree; return; }
        if (!cible.Current.IsEnabled) { res = "entree grisee : " + entree; return; }
        ((InvokePattern)cible.GetCurrentPattern(InvokePattern.Pattern)).Invoke();
        res = "ok";
      } catch (Exception e) { res = "EXCEPTION " + e.GetType().Name + " : " + e.Message; }
    });
    t.SetApartmentState(ApartmentState.STA); t.Start(); t.Join();
    return res;
  }
}
"@
}
$r = [StudioMenuUia]::Run($Bureau, $Menu, $Entree)
Write-Output $r
if ($r -eq 'ok') { exit 0 } else { exit 1 }
