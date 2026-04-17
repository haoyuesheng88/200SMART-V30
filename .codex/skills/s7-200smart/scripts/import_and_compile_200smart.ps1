param(
  [Parameter(Mandatory = $true)]
  [string]$AwlPath,

  [string[]]$ProcessName = @("MWSmart", "MWSmartV3"),
  [int]$MainNodeOffsetX = 93,
  [int]$MainNodeOffsetY = 263,
  [int]$ImportMenuOffsetX = 147,
  [int]$ImportMenuOffsetY = 486,
  [int]$CompileButtonOffsetX = 113,
  [int]$CompileButtonOffsetY = 78,
  [int]$WaitSeconds = 3,
  [string]$ScreenshotPath,
  [switch]$SkipImport,
  [switch]$SkipCompile
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path -LiteralPath $AwlPath)) {
  throw "AWL file not found: $AwlPath"
}
$AwlPath = (Resolve-Path -LiteralPath $AwlPath).Path

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName UIAutomationClient
Add-Type @'
using System;
using System.Text;
using System.Runtime.InteropServices;

public class SmartWin32 {
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr hWnd, out SmartRect rect);
  [DllImport("user32.dll")] public static extern void mouse_event(uint flags, uint dx, uint dy, uint data, UIntPtr extra);
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern IntPtr FindWindow(string cls, string name);
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern IntPtr SendMessage(IntPtr hWnd, int msg, IntPtr wParam, StringBuilder lParam);
  [DllImport("user32.dll")] public static extern IntPtr SendMessage(IntPtr hWnd, int msg, IntPtr wParam, IntPtr lParam);
}

public struct SmartRect {
  public int Left;
  public int Top;
  public int Right;
  public int Bottom;
}
'@

function Get-SmartProcess {
  foreach ($name in $ProcessName) {
    $proc = Get-Process -Name $name -ErrorAction SilentlyContinue |
      Where-Object { $_.MainWindowHandle -ne 0 } |
      Select-Object -First 1
    if ($proc) { return $proc }
  }
  throw "STEP 7-Micro/WIN SMART is not running. Tried process names: $($ProcessName -join ', ')"
}

function Get-WindowRectValue([IntPtr]$Handle) {
  [SmartRect]$rect = New-Object SmartRect
  [void][SmartWin32]::GetWindowRect($Handle, [ref]$rect)
  return $rect
}

function Click-At([int]$X, [int]$Y, [switch]$RightClick) {
  [System.Windows.Forms.Cursor]::Position = New-Object System.Drawing.Point($X, $Y)
  if ($RightClick) {
    [SmartWin32]::mouse_event(0x0008, 0, 0, 0, [UIntPtr]::Zero)
    Start-Sleep -Milliseconds 80
    [SmartWin32]::mouse_event(0x0010, 0, 0, 0, [UIntPtr]::Zero)
  } else {
    [SmartWin32]::mouse_event(0x0002, 0, 0, 0, [UIntPtr]::Zero)
    Start-Sleep -Milliseconds 80
    [SmartWin32]::mouse_event(0x0004, 0, 0, 0, [UIntPtr]::Zero)
  }
}

function Get-OutputWindowLines {
  $root = [System.Windows.Automation.AutomationElement]::RootElement
  $cond = New-Object System.Windows.Automation.PropertyCondition(
    [System.Windows.Automation.AutomationElement]::AutomationIdProperty,
    "20260"
  )
  $el = $root.FindFirst([System.Windows.Automation.TreeScope]::Subtree, $cond)
  if (-not $el) { return @("Output listbox not found") }

  $hwnd = [IntPtr]$el.Current.NativeWindowHandle
  $count = [SmartWin32]::SendMessage($hwnd, 0x018B, [IntPtr]::Zero, [IntPtr]::Zero).ToInt32()
  $lines = New-Object System.Collections.Generic.List[string]
  for ($i = 0; $i -lt $count; $i++) {
    $len = [SmartWin32]::SendMessage($hwnd, 0x018A, [IntPtr]$i, [IntPtr]::Zero).ToInt32()
    $sb = New-Object System.Text.StringBuilder ($len + 2)
    [void][SmartWin32]::SendMessage($hwnd, 0x0189, [IntPtr]$i, $sb)
    $lines.Add($sb.ToString())
  }
  return $lines.ToArray()
}

function Save-WindowScreenshot([IntPtr]$Handle, [string]$Path) {
  if (-not $Path) { return $null }
  $rect = Get-WindowRectValue $Handle
  $width = $rect.Right - $rect.Left
  $height = $rect.Bottom - $rect.Top
  $bmp = New-Object System.Drawing.Bitmap $width, $height
  $graphics = [System.Drawing.Graphics]::FromImage($bmp)
  try {
    $graphics.CopyFromScreen($rect.Left, $rect.Top, 0, 0, $bmp.Size)
    $bmp.Save($Path, [System.Drawing.Imaging.ImageFormat]::Png)
    return $Path
  } finally {
    $graphics.Dispose()
    $bmp.Dispose()
  }
}

$proc = Get-SmartProcess
$rect = Get-WindowRectValue $proc.MainWindowHandle
[void][SmartWin32]::SetForegroundWindow($proc.MainWindowHandle)
Start-Sleep -Milliseconds 300
[System.Windows.Forms.SendKeys]::SendWait("{ESC}")
Start-Sleep -Milliseconds 200

$importLines = @()
if (-not $SkipImport) {
  Click-At ($rect.Left + $MainNodeOffsetX) ($rect.Top + $MainNodeOffsetY) -RightClick
  Start-Sleep -Milliseconds 400
  Click-At ($rect.Left + $ImportMenuOffsetX) ($rect.Top + $ImportMenuOffsetY)
  Start-Sleep -Milliseconds 900

  $dialog = [SmartWin32]::FindWindow("#32770", $null)
  if ($dialog -eq [IntPtr]::Zero) {
    throw "Import dialog not found. Check project-tree and context-menu offsets."
  }
  [void][SmartWin32]::SetForegroundWindow($dialog)
  Start-Sleep -Milliseconds 200
  Set-Clipboard -Value $AwlPath
  [System.Windows.Forms.SendKeys]::SendWait("%n")
  Start-Sleep -Milliseconds 150
  [System.Windows.Forms.SendKeys]::SendWait("^a")
  Start-Sleep -Milliseconds 100
  [System.Windows.Forms.SendKeys]::SendWait("^v")
  Start-Sleep -Milliseconds 200
  [System.Windows.Forms.SendKeys]::SendWait("{ENTER}")
  Start-Sleep -Seconds $WaitSeconds
  [System.Windows.Forms.SendKeys]::SendWait("{ENTER}")
  Start-Sleep -Milliseconds 800
  $importLines = Get-OutputWindowLines
}

$compileLines = @()
if (-not $SkipCompile) {
  [void][SmartWin32]::SetForegroundWindow($proc.MainWindowHandle)
  Start-Sleep -Milliseconds 200
  [System.Windows.Forms.SendKeys]::SendWait("{ESC}")
  Start-Sleep -Milliseconds 200
  Click-At ($rect.Left + $CompileButtonOffsetX) ($rect.Top + $CompileButtonOffsetY)
  Start-Sleep -Seconds $WaitSeconds
  $compileLines = Get-OutputWindowLines
}

$screenshot = Save-WindowScreenshot $proc.MainWindowHandle $ScreenshotPath
$compileText = $compileLines -join "`n"
$zeroErrors = $compileText -match "\u9519\u8BEF\u603B\u8BA1\uFF1A0|0\s*\u4E2A\u9519\u8BEF|0\s+errors?"

[PSCustomObject]@{
  ProcessId = $proc.Id
  WindowTitle = $proc.MainWindowTitle
  AwlPath = $AwlPath
  ImportOutput = $importLines
  CompileOutput = $compileLines
  ZeroErrors = $zeroErrors
  ScreenshotPath = $screenshot
}
