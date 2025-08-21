# Script Launcher - Windows GUI для запуска скриптов
# Версия: 1.0
# Требования: Windows PowerShell 5.1+, .NET Framework
#
# ЦЕЛЬ: Централизованная панель управления для административных скриптов
# Больше не нужно искать по папкам - все скрипты в одном месте!
#
# ПРИМЕРЫ ИСПОЛЬЗОВАНИЯ:
# • 🔑 Смена пароля пользователя в AD
# • 👥 Создание/удаление пользователей
# • 🔒 Блокировка/разблокировка учетных записей
# • 📁 Управление правами доступа к папкам
# • 🌐 Настройка сетевых политик
# • 📊 Генерация отчетов по пользователям
# • 💾 Скрипты резервного копирования
# • 🔧 Системное администрирование
#
# БЫСТРЫЙ СТАРТ:
# 1. Запустить ScriptLauncher.ps1
# 2. Добавить свои скрипты через кнопки "➕ AD скрипт", "➕ Пользователи" и т.д.
# 3. Указать путь к скрипту (двойной клик на колонку "Путь")
# 4. Настроить аргументы и описание
# 5. Сохранить и запускать одной кнопкой!

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Глобальные переменные
$script:ConfigPath = Join-Path $PSScriptRoot "config.json"
$script:Scripts = @()
$script:Form = $null
$script:DataGridView = $null

# Класс для представления скрипта
class ScriptEntry {
    [string]$Name
    [string]$Path
    [string]$Runner
    [bool]$AskArgs
    [string]$DefaultArgs
    [string]$Category
    [string]$Description
    
    ScriptEntry() {
        $this.Name = ""
        $this.Path = ""
        $this.Runner = "PowerShell"
        $this.AskArgs = $false
        $this.DefaultArgs = ""
        $this.Category = "General"
        $this.Description = ""
    }
}

# Функция загрузки конфигурации
function Load-Config {
    try {
        if (Test-Path $script:ConfigPath) {
            $jsonContent = Get-Content $script:ConfigPath -Raw -Encoding UTF8
            $configData = ConvertFrom-Json $jsonContent
            
            $script:Scripts = @()
            foreach ($item in $configData.Scripts) {
                $scriptEntry = [ScriptEntry]::new()
                $scriptEntry.Name = $item.Name
                $scriptEntry.Path = $item.Path
                $scriptEntry.Runner = $item.Runner
                $scriptEntry.AskArgs = $item.AskArgs
                $scriptEntry.DefaultArgs = $item.DefaultArgs
                $scriptEntry.Category = if ($item.Category) { $item.Category } else { "General" }
                $scriptEntry.Description = if ($item.Description) { $item.Description } else { "" }
                $script:Scripts += $scriptEntry
            }
        }
    }
    catch {
        [System.Windows.Forms.MessageBox]::Show("Ошибка загрузки конфигурации: $($_.Exception.Message)", "Ошибка", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
    }
}

# Функция сохранения конфигурации
function Save-Config {
    try {
        $configData = @{
            Scripts = @()
        }
        
        foreach ($script in $script:Scripts) {
            $configData.Scripts += @{
                Name = $script.Name
                Path = $script.Path
                Runner = $script.Runner
                AskArgs = $script.AskArgs
                DefaultArgs = $script.DefaultArgs
                Category = $script.Category
                Description = $script.Description
            }
        }
        
        $jsonContent = ConvertTo-Json $configData -Depth 3 -Compress:$false
        [System.IO.File]::WriteAllText($script:ConfigPath, $jsonContent, [System.Text.Encoding]::UTF8)
        
        [System.Windows.Forms.MessageBox]::Show("Конфигурация сохранена успешно", "Сохранение", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
    }
    catch {
        [System.Windows.Forms.MessageBox]::Show("Ошибка сохранения конфигурации: $($_.Exception.Message)", "Ошибка", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
    }
}

# Функция фильтрации скриптов
function Filter-Scripts {
    param([string]$SearchText)
    
    $script:DataGridView.Rows.Clear()
    
    $filteredScripts = if ([string]::IsNullOrWhiteSpace($SearchText)) {
        $script:Scripts
    } else {
        $script:Scripts | Where-Object { 
            $_.Name -like "*$SearchText*" -or 
            $_.Category -like "*$SearchText*" -or 
            $_.Description -like "*$SearchText*" 
        }
    }
    
    foreach ($scriptEntry in $filteredScripts) {
        $row = New-Object System.Windows.Forms.DataGridViewRow
        $row.Cells.Add((New-Object System.Windows.Forms.DataGridViewTextBoxCell -Property @{Value = $scriptEntry.Name}))
        $row.Cells.Add((New-Object System.Windows.Forms.DataGridViewTextBoxCell -Property @{Value = $scriptEntry.Path}))
        
        # ComboBox для Runner
        $runnerCell = New-Object System.Windows.Forms.DataGridViewComboBoxCell
        $runnerCell.Items.AddRange(@("PowerShell", "CMD", "WSL"))
        $runnerCell.Value = $scriptEntry.Runner
        $row.Cells.Add($runnerCell)
        
        # CheckBox для AskArgs
        $askArgsCell = New-Object System.Windows.Forms.DataGridViewCheckBoxCell
        $askArgsCell.Value = $scriptEntry.AskArgs
        $row.Cells.Add($askArgsCell)
        
        $row.Cells.Add((New-Object System.Windows.Forms.DataGridViewTextBoxCell -Property @{Value = $scriptEntry.DefaultArgs}))
        
        # ComboBox для Category
        $categoryCell = New-Object System.Windows.Forms.DataGridViewComboBoxCell
        $categoryCell.Items.AddRange(@("General", "Active Directory", "Users", "Network", "Security", "Reports", "Backup", "System"))
        $categoryCell.Value = $scriptEntry.Category
        $row.Cells.Add($categoryCell)
        
        $row.Cells.Add((New-Object System.Windows.Forms.DataGridViewTextBoxCell -Property @{Value = $scriptEntry.Description}))
        
        $script:DataGridView.Rows.Add($row)
    }
}

# Функция обновления таблицы
function Update-DataGrid {
    Filter-Scripts ""
}

# Функция добавления нового скрипта
function Add-NewScript {
    $script:Scripts += [ScriptEntry]::new()
    Update-DataGrid
    
    # Выделить новую строку для редактирования
    $lastRowIndex = $script:DataGridView.Rows.Count - 1
    $script:DataGridView.CurrentCell = $script:DataGridView.Rows[$lastRowIndex].Cells[0]
    $script:DataGridView.BeginEdit($true)
}

# Функция добавления шаблона скрипта
function Add-TemplateScript {
    param(
        [string]$Category,
        [string]$Name,
        [string]$Runner,
        [bool]$AskArgs,
        [string]$Description
    )
    
    $newScript = [ScriptEntry]::new()
    $newScript.Name = $Name
    $newScript.Category = $Category
    $newScript.Runner = $Runner
    $newScript.AskArgs = $AskArgs
    $newScript.Description = $Description
    
    $script:Scripts += $newScript
    Update-DataGrid
    
    # Выделить новую строку для редактирования
    $lastRowIndex = $script:DataGridView.Rows.Count - 1
    $script:DataGridView.CurrentCell = $script:DataGridView.Rows[$lastRowIndex].Cells[1] # Фокус на Path
    $script:DataGridView.BeginEdit($true)
}

# Функция удаления скрипта
function Remove-Script {
    $selectedRows = $script:DataGridView.SelectedRows
    if ($selectedRows.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show("Выберите строку для удаления", "Внимание", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
        return
    }
    
    $result = [System.Windows.Forms.MessageBox]::Show("Удалить выбранные скрипты?", "Подтверждение", [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Question)
    if ($result -eq [System.Windows.Forms.DialogResult]::Yes) {
        # Сортируем индексы по убыванию для корректного удаления
        $indices = @()
        foreach ($row in $selectedRows) {
            $indices += $row.Index
        }
        $indices = $indices | Sort-Object -Descending
        
        foreach ($index in $indices) {
            if ($index -lt $script:Scripts.Count) {
                $script:Scripts = $script:Scripts | Where-Object { $script:Scripts.IndexOf($_) -ne $index }
            }
        }
        
        Update-DataGrid
    }
}

# Функция конвертации Windows пути в WSL путь
function Convert-ToWSLPath {
    param([string]$WindowsPath)
    
    if ($WindowsPath -match '^([A-Za-z]):(.*)$') {
        $drive = $matches[1].ToLower()
        $path = $matches[2] -replace '\\', '/'
        return "/mnt/$drive$path"
    }
    return $WindowsPath
}

# Функция запуска скрипта
function Run-Script {
    $selectedRows = $script:DataGridView.SelectedRows
    if ($selectedRows.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show("Выберите скрипт для запуска", "Внимание", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
        return
    }
    
    if ($selectedRows.Count -gt 1) {
        [System.Windows.Forms.MessageBox]::Show("Выберите только один скрипт для запуска", "Внимание", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
        return
    }
    
    $selectedIndex = $selectedRows[0].Index
    if ($selectedIndex -ge $script:Scripts.Count) {
        [System.Windows.Forms.MessageBox]::Show("Неверный индекс скрипта", "Ошибка", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
        return
    }
    
    $selectedScript = $script:Scripts[$selectedIndex]
    
    # Проверка существования файла (кроме WSL)
    if ($selectedScript.Runner -ne "WSL" -and -not (Test-Path $selectedScript.Path)) {
        [System.Windows.Forms.MessageBox]::Show("Файл не найден: $($selectedScript.Path)", "Ошибка", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
        return
    }
    
    # Получение аргументов
    $args = $selectedScript.DefaultArgs
    if ($selectedScript.AskArgs) {
        $inputForm = New-Object System.Windows.Forms.Form
        $inputForm.Text = "Аргументы для: $($selectedScript.Name)"
        $inputForm.Size = New-Object System.Drawing.Size(400, 150)
        $inputForm.StartPosition = "CenterParent"
        $inputForm.FormBorderStyle = "FixedDialog"
        $inputForm.MaximizeBox = $false
        $inputForm.MinimizeBox = $false
        
        $label = New-Object System.Windows.Forms.Label
        $label.Text = "Введите аргументы командной строки:"
        $label.Location = New-Object System.Drawing.Point(10, 15)
        $label.Size = New-Object System.Drawing.Size(370, 20)
        $inputForm.Controls.Add($label)
        
        $textBox = New-Object System.Windows.Forms.TextBox
        $textBox.Location = New-Object System.Drawing.Point(10, 40)
        $textBox.Size = New-Object System.Drawing.Size(360, 25)
        $textBox.Text = $selectedScript.DefaultArgs
        $inputForm.Controls.Add($textBox)
        
        $okButton = New-Object System.Windows.Forms.Button
        $okButton.Text = "OK"
        $okButton.Location = New-Object System.Drawing.Point(215, 75)
        $okButton.Size = New-Object System.Drawing.Size(75, 25)
        $okButton.DialogResult = [System.Windows.Forms.DialogResult]::OK
        $inputForm.Controls.Add($okButton)
        
        $cancelButton = New-Object System.Windows.Forms.Button
        $cancelButton.Text = "Отмена"
        $cancelButton.Location = New-Object System.Drawing.Point(295, 75)
        $cancelButton.Size = New-Object System.Drawing.Size(75, 25)
        $cancelButton.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
        $inputForm.Controls.Add($cancelButton)
        
        $inputForm.AcceptButton = $okButton
        $inputForm.CancelButton = $cancelButton
        
        $result = $inputForm.ShowDialog($script:Form)
        if ($result -eq [System.Windows.Forms.DialogResult]::Cancel) {
            return
        }
        
        $args = $textBox.Text
    }
    
    try {
        # Экранирование пути и аргументов
        $quotedPath = "`"$($selectedScript.Path)`""
        $processArgs = ""
        
        switch ($selectedScript.Runner) {
            "PowerShell" {
                $processArgs = "-ExecutionPolicy Bypass -NoProfile -File $quotedPath"
                if ($args.Trim() -ne "") {
                    $processArgs += " $args"
                }
                Start-Process "powershell.exe" -ArgumentList $processArgs
            }
            "CMD" {
                $processArgs = "/c $quotedPath"
                if ($args.Trim() -ne "") {
                    $processArgs += " $args"
                }
                Start-Process "cmd.exe" -ArgumentList $processArgs
            }
            "WSL" {
                $wslPath = Convert-ToWSLPath $selectedScript.Path
                $bashCommand = $wslPath
                if ($args.Trim() -ne "") {
                    $bashCommand += " $args"
                }
                # Экранирование для WSL
                $bashCommand = $bashCommand -replace "'", "'\''"
                Start-Process "wsl.exe" -ArgumentList "bash", "-c", "'$bashCommand'"
            }
            default {
                [System.Windows.Forms.MessageBox]::Show("Неизвестный тип запуска: $($selectedScript.Runner)", "Ошибка", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
                return
            }
        }
        
        Write-Host "Запущен скрипт: $($selectedScript.Name) с аргументами: $args"
    }
    catch {
        [System.Windows.Forms.MessageBox]::Show("Ошибка запуска скрипта: $($_.Exception.Message)", "Ошибка", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
    }
}

# Функция синхронизации данных из таблицы обратно в массив
function Sync-DataFromGrid {
    for ($i = 0; $i -lt [Math]::Min($script:DataGridView.Rows.Count, $script:Scripts.Count); $i++) {
        $row = $script:DataGridView.Rows[$i]
        $script:Scripts[$i].Name = $row.Cells[0].Value
        $script:Scripts[$i].Path = $row.Cells[1].Value
        $script:Scripts[$i].Runner = $row.Cells[2].Value
        $script:Scripts[$i].AskArgs = $row.Cells[3].Value
        $script:Scripts[$i].DefaultArgs = $row.Cells[4].Value
        $script:Scripts[$i].Category = $row.Cells[5].Value
        $script:Scripts[$i].Description = $row.Cells[6].Value
    }
}

# Создание главной формы
function Create-MainForm {
    $script:Form = New-Object System.Windows.Forms.Form
    $script:Form.Text = "🚀 Script Launcher v1.0 - Централизованная панель управления скриптами"
    $script:Form.Size = New-Object System.Drawing.Size(1100, 500)
    $script:Form.StartPosition = "CenterScreen"
    $script:Form.MinimumSize = New-Object System.Drawing.Size(1000, 400)
    
    # Панель поиска
    $searchPanel = New-Object System.Windows.Forms.Panel
    $searchPanel.Location = New-Object System.Drawing.Point(10, 10)
    $searchPanel.Size = New-Object System.Drawing.Size(1060, 35)
    $searchPanel.Anchor = "Top,Left,Right"
    
    $searchLabel = New-Object System.Windows.Forms.Label
    $searchLabel.Text = "Поиск:"
    $searchLabel.Location = New-Object System.Drawing.Point(0, 8)
    $searchLabel.Size = New-Object System.Drawing.Size(50, 20)
    $searchPanel.Controls.Add($searchLabel)
    
    $searchBox = New-Object System.Windows.Forms.TextBox
    $searchBox.Location = New-Object System.Drawing.Point(55, 5)
    $searchBox.Size = New-Object System.Drawing.Size(200, 25)
    $searchBox.add_TextChanged({
        Filter-Scripts $searchBox.Text
    })
    $searchPanel.Controls.Add($searchBox)
    
    $clearButton = New-Object System.Windows.Forms.Button
    $clearButton.Text = "Очистить"
    $clearButton.Location = New-Object System.Drawing.Point(265, 5)
    $clearButton.Size = New-Object System.Drawing.Size(70, 25)
    $clearButton.add_Click({
        $searchBox.Text = ""
        Filter-Scripts ""
    })
    $searchPanel.Controls.Add($clearButton)
    
    $script:Form.Controls.Add($searchPanel)
    
    # Создание таблицы
    $script:DataGridView = New-Object System.Windows.Forms.DataGridView
    $script:DataGridView.Location = New-Object System.Drawing.Point(10, 50)
    $script:DataGridView.Size = New-Object System.Drawing.Size(1060, 330)
    $script:DataGridView.Anchor = "Top,Bottom,Left,Right"
    $script:DataGridView.AllowUserToAddRows = $false
    $script:DataGridView.AllowUserToDeleteRows = $false
    $script:DataGridView.SelectionMode = "FullRowSelect"
    $script:DataGridView.MultiSelect = $true
    $script:DataGridView.AutoSizeColumnsMode = "Fill"
    
    # Добавление колонок
    $nameColumn = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
    $nameColumn.Name = "Name"
    $nameColumn.HeaderText = "Название"
    $nameColumn.FillWeight = 20
    $script:DataGridView.Columns.Add($nameColumn)
    
    $pathColumn = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
    $pathColumn.Name = "Path"
    $pathColumn.HeaderText = "Путь"
    $pathColumn.FillWeight = 30
    $script:DataGridView.Columns.Add($pathColumn)
    
    $runnerColumn = New-Object System.Windows.Forms.DataGridViewComboBoxColumn
    $runnerColumn.Name = "Runner"
    $runnerColumn.HeaderText = "Запуск"
    $runnerColumn.FillWeight = 12
    $runnerColumn.Items.AddRange(@("PowerShell", "CMD", "WSL"))
    $script:DataGridView.Columns.Add($runnerColumn)
    
    $askArgsColumn = New-Object System.Windows.Forms.DataGridViewCheckBoxColumn
    $askArgsColumn.Name = "AskArgs"
    $askArgsColumn.HeaderText = "Спросить аргументы"
    $askArgsColumn.FillWeight = 15
    $script:DataGridView.Columns.Add($askArgsColumn)
    
    $defaultArgsColumn = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
    $defaultArgsColumn.Name = "DefaultArgs"
    $defaultArgsColumn.HeaderText = "Аргументы"
    $defaultArgsColumn.FillWeight = 18
    $script:DataGridView.Columns.Add($defaultArgsColumn)
    
    $categoryColumn = New-Object System.Windows.Forms.DataGridViewComboBoxColumn
    $categoryColumn.Name = "Category"
    $categoryColumn.HeaderText = "Категория"
    $categoryColumn.FillWeight = 15
    $categoryColumn.Items.AddRange(@("General", "Active Directory", "Users", "Network", "Security", "Reports", "Backup", "System"))
    $script:DataGridView.Columns.Add($categoryColumn)
    
    $descriptionColumn = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
    $descriptionColumn.Name = "Description"
    $descriptionColumn.HeaderText = "Описание"
    $descriptionColumn.FillWeight = 25
    $script:DataGridView.Columns.Add($descriptionColumn)
    
    # Обработчик двойного клика на ячейку пути
    $script:DataGridView.add_CellDoubleClick({
        param($sender, $e)
        if ($e.ColumnIndex -eq 1) { # Колонка Path
            $openFileDialog = New-Object System.Windows.Forms.OpenFileDialog
            $openFileDialog.Title = "Выберите файл скрипта"
            $openFileDialog.Filter = "Все поддерживаемые файлы (*.ps1;*.bat;*.cmd;*.exe;*.sh)|*.ps1;*.bat;*.cmd;*.exe;*.sh|PowerShell скрипты (*.ps1)|*.ps1|Batch файлы (*.bat;*.cmd)|*.bat;*.cmd|Исполняемые файлы (*.exe)|*.exe|Shell скрипты (*.sh)|*.sh|Все файлы (*.*)|*.*"
            
            if ($openFileDialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
                $script:DataGridView.Rows[$e.RowIndex].Cells[$e.ColumnIndex].Value = $openFileDialog.FileName
            }
        }
    })
    
    # Обработчик изменения ячеек для синхронизации данных
    $script:DataGridView.add_CellValueChanged({
        Sync-DataFromGrid
    })
    
    $script:Form.Controls.Add($script:DataGridView)
    
    # Панель кнопок
    $buttonPanel = New-Object System.Windows.Forms.Panel
    $buttonPanel.Location = New-Object System.Drawing.Point(10, 390)
    $buttonPanel.Size = New-Object System.Drawing.Size(1060, 50)
    $buttonPanel.Anchor = "Bottom,Left,Right"
    
    # Кнопка "Добавить"
    $addButton = New-Object System.Windows.Forms.Button
    $addButton.Text = "Добавить"
    $addButton.Location = New-Object System.Drawing.Point(0, 10)
    $addButton.Size = New-Object System.Drawing.Size(80, 30)
    $addButton.add_Click({ Add-NewScript })
    $buttonPanel.Controls.Add($addButton)
    
    # Кнопка "Удалить"
    $deleteButton = New-Object System.Windows.Forms.Button
    $deleteButton.Text = "Удалить"
    $deleteButton.Location = New-Object System.Drawing.Point(90, 10)
    $deleteButton.Size = New-Object System.Drawing.Size(80, 30)
    $deleteButton.add_Click({ Remove-Script })
    $buttonPanel.Controls.Add($deleteButton)
    
    # Кнопка "Запустить"
    $runButton = New-Object System.Windows.Forms.Button
    $runButton.Text = "Запустить"
    $runButton.Location = New-Object System.Drawing.Point(180, 10)
    $runButton.Size = New-Object System.Drawing.Size(80, 30)
    $runButton.add_Click({ 
        Sync-DataFromGrid
        Run-Script 
    })
    $buttonPanel.Controls.Add($runButton)
    
    # Кнопка "Сохранить"
    $saveButton = New-Object System.Windows.Forms.Button
    $saveButton.Text = "Сохранить"
    $saveButton.Location = New-Object System.Drawing.Point(270, 10)
    $saveButton.Size = New-Object System.Drawing.Size(80, 30)
    $saveButton.add_Click({ 
        Sync-DataFromGrid
        Save-Config 
    })
    $buttonPanel.Controls.Add($saveButton)
    
    # Разделитель
    $separator = New-Object System.Windows.Forms.Label
    $separator.Text = "|"
    $separator.Location = New-Object System.Drawing.Point(360, 15)
    $separator.Size = New-Object System.Drawing.Size(10, 20)
    $separator.ForeColor = [System.Drawing.Color]::Gray
    $buttonPanel.Controls.Add($separator)
    
    # Кнопки быстрого добавления шаблонов
    $addADButton = New-Object System.Windows.Forms.Button
    $addADButton.Text = "➕ AD скрипт"
    $addADButton.Location = New-Object System.Drawing.Point(380, 10)
    $addADButton.Size = New-Object System.Drawing.Size(100, 30)
    $addADButton.BackColor = [System.Drawing.Color]::LightBlue
    $addADButton.add_Click({ 
        Add-TemplateScript "Active Directory" "Новый AD скрипт" "PowerShell" $true "Скрипт для работы с Active Directory"
    })
    $buttonPanel.Controls.Add($addADButton)
    
    $addUserButton = New-Object System.Windows.Forms.Button
    $addUserButton.Text = "➕ Пользователи"
    $addUserButton.Location = New-Object System.Drawing.Point(490, 10)
    $addUserButton.Size = New-Object System.Drawing.Size(110, 30)
    $addUserButton.BackColor = [System.Drawing.Color]::LightGreen
    $addUserButton.add_Click({ 
        Add-TemplateScript "Users" "Управление пользователями" "PowerShell" $true "Скрипт для управления пользователями"
    })
    $buttonPanel.Controls.Add($addUserButton)
    
    $addNetworkButton = New-Object System.Windows.Forms.Button
    $addNetworkButton.Text = "➕ Сеть"
    $addNetworkButton.Location = New-Object System.Drawing.Point(610, 10)
    $addNetworkButton.Size = New-Object System.Drawing.Size(80, 30)
    $addNetworkButton.BackColor = [System.Drawing.Color]::LightYellow
    $addNetworkButton.add_Click({ 
        Add-TemplateScript "Network" "Сетевой скрипт" "PowerShell" $false "Скрипт для работы с сетью"
    })
    $buttonPanel.Controls.Add($addNetworkButton)
    
    $script:Form.Controls.Add($buttonPanel)
    
    # нужно что бы закрыть форму 
    $script:Form.add_FormClosing({
        Sync-DataFromGrid
    })
}

# main
function Main {
    try {
        Write-Host "Запуск Script Launcher..."
        
        # загрузка конфига
        Load-Config
        
        
        Create-MainForm
        Update-DataGrid
        
        Write-Host "GUI"
        [System.Windows.Forms.Application]::Run($script:Form)
    }
    catch {
        Write-Host "Критическая ошибка: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host $_.ScriptStackTrace -ForegroundColor Red
        [System.Windows.Forms.MessageBox]::Show("Критическая ошибка приложения: $($_.Exception.Message)", "Критическая ошибка", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
    }
}

# Запуск приложения
Main