param(
  [string]$AwlPath,
  [switch]$UseBundledBagPulse4,
  [int]$FileTabOffsetX = 81,
  [int]$FileTabOffsetY = 40,
  [int]$ImportSplitOffsetX = 205,
  [int]$ImportSplitOffsetY = 68,
  [int]$ImportPouOffsetX = 195,
  [int]$ImportPouOffsetY = 92,
  [int]$PlcTabOffsetX = 239,
  [int]$PlcTabOffsetY = 40,
  [int]$CompileButtonOffsetX = 293,
  [int]$CompileButtonOffsetY = 89,
  [int]$WaitSeconds = 3,
  [string]$ScreenshotPath,
  [switch]$SkipImport,
  [switch]$SkipCompile
)

$ErrorActionPreference = "Stop"

if ($UseBundledBagPulse4 -and -not $AwlPath) {
  $AwlPath = Join-Path $PSScriptRoot "..\\assets\\bag-pulse-dust-collector-4bags-ob1.awl"
}

if (-not $SkipImport) {
  if (-not $AwlPath) {
    throw "Provide -AwlPath or use -UseBundledBagPulse4."
  }
  if (-not (Test-Path -LiteralPath $AwlPath)) {
    throw "AWL file not found: $AwlPath"
  }
  $AwlPath = (Resolve-Path -LiteralPath $AwlPath).Path
}

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName UIAutomationClient
Add-Type @'
using System;
using System.Text;
using System.Runtime.InteropServices;

public class SmartWin32V3 {
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

$ImportDialogTitle = -join ([char[]](0x5BFC,0x5165,0x7A0B,0x5E8F,0x5757))
$ZeroErrorSummary = -join ([char[]](0x9519,0x8BEF,0x603B,0x8BA1,0xFF1A,0x0030))

function Get-SmartProcess {
  $proc = Get-Process -Name "MWSmartV3" -ErrorAction SilentlyContinue |
    Where-Object { $_.MainWindowHandle -ne 0 } |
    Select-Object -First 1
  if (-not $proc) {
    throw "STEP 7-Micro/WIN SMART V3 is not running. Expected process name MWSmartV3."
  }
  return $proc
}

function Get-WindowRectValue([IntPtr]$Handle) {
  [SmartRect]$rect = New-Object SmartRect
  [void][SmartWin32V3]::GetWindowRect($Handle, [ref]$rect)
  return $rect
}

function Click-At([int]$X, [int]$Y) {
  [System.Windows.Forms.Cursor]::Position = New-Object System.Drawing.Point($X, $Y)
  [SmartWin32V3]::mouse_event(0x0002, 0, 0, 0, [UIntPtr]::Zero)
  Start-Sleep -Milliseconds 80
  [SmartWin32V3]::mouse_event(0x0004, 0, 0, 0, [UIntPtr]::Zero)
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
  $count = [SmartWin32V3]::SendMessage($hwnd, 0x018B, [IntPtr]::Zero, [IntPtr]::Zero).ToInt32()
  $lines = New-Object System.Collections.Generic.List[string]
  for ($i = 0; $i -lt $count; $i++) {
    $len = [SmartWin32V3]::SendMessage($hwnd, 0x018A, [IntPtr]$i, [IntPtr]::Zero).ToInt32()
    $sb = New-Object System.Text.StringBuilder ($len + 2)
    [void][SmartWin32V3]::SendMessage($hwnd, 0x0189, [IntPtr]$i, $sb)
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

function Open-ImportDialog([SmartRect]$Rect) {
  Click-At ($Rect.Left + $FileTabOffsetX) ($Rect.Top + $FileTabOffsetY)
  Start-Sleep -Milliseconds 250
  Click-At ($Rect.Left + $ImportSplitOffsetX) ($Rect.Top + $ImportSplitOffsetY)
  Start-Sleep -Milliseconds 250
  Click-At ($Rect.Left + $ImportPouOffsetX) ($Rect.Top + $ImportPouOffsetY)
  Start-Sleep -Milliseconds 900
}

function Submit-AwlPath([string]$Path) {
  $dialog = [SmartWin32V3]::FindWindow("#32770", $ImportDialogTitle)
  if ($dialog -eq [IntPtr]::Zero) {
    $dialog = [SmartWin32V3]::FindWindow("#32770", $null)
  }
  if ($dialog -eq [IntPtr]::Zero) {
    throw "Import dialog not found. Check the V3 ribbon offsets."
  }

  [void][SmartWin32V3]::SetForegroundWindow($dialog)
  Start-Sleep -Milliseconds 200
  Set-Clipboard -Value $Path
  [System.Windows.Forms.SendKeys]::SendWait("%n")
  Start-Sleep -Milliseconds 120
  [System.Windows.Forms.SendKeys]::SendWait("^a")
  Start-Sleep -Milliseconds 80
  [System.Windows.Forms.SendKeys]::SendWait("^v")
  Start-Sleep -Milliseconds 150
  [System.Windows.Forms.SendKeys]::SendWait("{ENTER}")
}

function Dismiss-NoPrompt([int]$Attempts = 8) {
  for ($i = 0; $i -lt $Attempts; $i++) {
    Start-Sleep -Milliseconds 250
    $dialog = [SmartWin32V3]::FindWindow("#32770", $null)
    if ($dialog -eq [IntPtr]::Zero) { continue }
    [void][SmartWin32V3]::SetForegroundWindow($dialog)
    Start-Sleep -Milliseconds 120
    $dialogRect = Get-WindowRectValue $dialog
    Click-At ($dialogRect.Left + 176) ($dialogRect.Top + 145)
  }
}

$proc = Get-SmartProcess
[void][SmartWin32V3]::SetForegroundWindow($proc.MainWindowHandle)
Start-Sleep -Milliseconds 300
[System.Windows.Forms.SendKeys]::SendWait("{ESC}")
Start-Sleep -Milliseconds 200
$rect = Get-WindowRectValue $proc.MainWindowHandle

$importLines = @()
if (-not $SkipImport) {
  Open-ImportDialog $rect
  Submit-AwlPath $AwlPath
  Dismiss-NoPrompt
  Start-Sleep -Seconds $WaitSeconds
  $importLines = Get-OutputWindowLines
}

$compileLines = @()
if (-not $SkipCompile) {
  [void][SmartWin32V3]::SetForegroundWindow($proc.MainWindowHandle)
  Start-Sleep -Milliseconds 200
  [System.Windows.Forms.SendKeys]::SendWait("{ESC}")
  Start-Sleep -Milliseconds 120
  Click-At ($rect.Left + $PlcTabOffsetX) ($rect.Top + $PlcTabOffsetY)
  Start-Sleep -Milliseconds 250
  Click-At ($rect.Left + $CompileButtonOffsetX) ($rect.Top + $CompileButtonOffsetY)
  Start-Sleep -Seconds $WaitSeconds
  $compileLines = Get-OutputWindowLines
}

$screenshot = Save-WindowScreenshot $proc.MainWindowHandle $ScreenshotPath
$compileText = $compileLines -join "`n"
$zeroErrors = $compileText.Contains($ZeroErrorSummary) -or ($compileText -match "0\s+errors?")

[PSCustomObject]@{
  ProcessId = $proc.Id
  WindowTitle = $proc.MainWindowTitle
  AwlPath = $AwlPath
  ImportOutput = $importLines
  CompileOutput = $compileLines
  ZeroErrors = $zeroErrors
  ScreenshotPath = $screenshot
}
