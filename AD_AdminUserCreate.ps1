<#
================================================================================
 ACTIVE DIRECTORY BENUTZERVERWALTUNG (RSAT-MODUL ENGINE)
 Register:
   1. Normaler User (Kopieren: DataGridView mit Checkboxen, Name & Description)
   2. Install-User  (Präfix wählbar, Default: install)
   3. ladm-User     (Local Admin, Default: ladm)
   4. Domain Admin  (Tier-0 DAdm Standard lt. Screenshot, Default: dadm)
================================================================================
#>

# 1. Modul-Check
if (-not (Get-Module -ListAvailable -Name ActiveDirectory)) {
    Add-Type -AssemblyName System.Windows.Forms
    [System.Windows.Forms.MessageBox]::Show(
        "Das PowerShell-Modul 'ActiveDirectory' (RSAT) ist nicht installiert.`r`nBitte installieren Sie RSAT über die Windows-Features.",
        "RSAT fehlt",
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Error
    )
    return
}
Import-Module ActiveDirectory -ErrorAction Stop

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

# 2. Design-Konfiguration
$UITheme = @{
    TitleFont       = New-Object System.Drawing.Font("Segoe UI", 10.5, [System.Drawing.FontStyle]::Bold)
    SectionFont     = New-Object System.Drawing.Font("Segoe UI", 9.5, [System.Drawing.FontStyle]::Bold)
    LabelFont       = New-Object System.Drawing.Font("Segoe UI", 9.0, [System.Drawing.FontStyle]::Bold)
    InputFont       = New-Object System.Drawing.Font("Segoe UI", 9.5, [System.Drawing.FontStyle]::Regular)
    GridFont        = New-Object System.Drawing.Font("Segoe UI", 9.0, [System.Drawing.FontStyle]::Regular)
    GridHeaderFont  = New-Object System.Drawing.Font("Segoe UI", 9.0, [System.Drawing.FontStyle]::Bold)
    ButtonFont      = New-Object System.Drawing.Font("Segoe UI", 9.5, [System.Drawing.FontStyle]::Bold)
    AccentColor     = [System.Drawing.Color]::FromArgb(0, 78, 162)
    HeaderBack      = [System.Drawing.Color]::FromArgb(238, 242, 246)
}

function Show-ADUserManagementSuite {
    try {
        $domainInfo = Get-ADDomain -ErrorAction Stop
        $domainDN   = $domainInfo.DistinguishedName
        $upnSuffix  = $domainInfo.DnsRoot
    } catch {
        [System.Windows.Forms.MessageBox]::Show("Active Directory Domäne nicht erreichbar.", "Verbindungsfehler", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
        return
    }

    # OUs einlesen
    $allOUs = @(Get-ADOrganizationalUnit -Filter * | Sort-Object DistinguishedName | Select-Object -ExpandProperty DistinguishedName)
    $allOUs += "CN=Users,$domainDN"

    $form = New-Object System.Windows.Forms.Form
    $form.Text = "Active Directory Management - Benutzerverwaltung"
    $form.Size = New-Object System.Drawing.Size(1300, 920)
    $form.MinimumSize = New-Object System.Drawing.Size(1100, 750)
    $form.StartPosition = "CenterScreen"
    $form.Font = $UITheme.InputFont
    $form.BackColor = [System.Drawing.Color]::FromArgb(246, 248, 251)

    $tabs = New-Object System.Windows.Forms.TabControl
    $tabs.Dock = [System.Windows.Forms.DockStyle]::Fill
    $tabs.Font = $UITheme.LabelFont
    $tabs.ItemSize = New-Object System.Drawing.Size(200, 32)
    $form.Controls.Add($tabs)

    function Add-FormInputRow($tbl, $row, $labelText, $control) {
        $lbl = New-Object System.Windows.Forms.Label
        $lbl.Text = $labelText
        $lbl.Font = $UITheme.LabelFont
        $lbl.Dock = [System.Windows.Forms.DockStyle]::Fill
        $lbl.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
        $lbl.Margin = New-Object System.Windows.Forms.Padding(3)

        $control.Dock = [System.Windows.Forms.DockStyle]::Fill
        $control.Font = $UITheme.InputFont
        $control.Margin = New-Object System.Windows.Forms.Padding(3, 4, 3, 4)

        $tbl.Controls.Add($lbl, 0, $row)
        $tbl.Controls.Add($control, 1, $row)
    }

    # ==========================================================================
    # REGISTER 1: NORMALER USER (KOPIEREN MIT GRUPPEN-DESCRIPTION)
    # ==========================================================================
    $tab1 = New-Object System.Windows.Forms.TabPage
    $tab1.Text = "1. Normaler User (Kopieren)"
    $tab1.Padding = New-Object System.Windows.Forms.Padding(10)
    $tabs.Controls.Add($tab1)

    $splitT1 = New-Object System.Windows.Forms.SplitContainer
    $splitT1.Dock = [System.Windows.Forms.DockStyle]::Fill
    $splitT1.SplitterDistance = 750
    $splitT1.SplitterWidth = 6
    $tab1.Controls.Add($splitT1)

    # Links: Gruppen-Grid
    $grpT1Left = New-Object System.Windows.Forms.GroupBox
    $grpT1Left.Text = "Quell-Benutzer (Gruppen-Filter / Abwahl)"
    $grpT1Left.Dock = [System.Windows.Forms.DockStyle]::Fill
    $grpT1Left.Font = $UITheme.SectionFont
    $splitT1.Panel1.Controls.Add($grpT1Left)

    $pnlT1Search = New-Object System.Windows.Forms.Panel
    $pnlT1Search.Dock = [System.Windows.Forms.DockStyle]::Top
    $pnlT1Search.Height = 85
    $grpT1Left.Controls.Add($pnlT1Search)

    $txtT1Source = New-Object System.Windows.Forms.TextBox; $txtT1Source.Location = "10, 12"; $txtT1Source.Size = "260, 25"; $pnlT1Search.Controls.Add($txtT1Source)
    $btnT1Load = New-Object System.Windows.Forms.Button; $btnT1Load.Text = "Gruppen laden"; $btnT1Load.Location = "280, 10"; $btnT1Load.Size = "150, 29"
    $btnT1Load.BackColor = [System.Drawing.Color]::FromArgb(0, 102, 204); $btnT1Load.ForeColor = [System.Drawing.Color]::White; $btnT1Load.FlatStyle = "Flat"
    $btnT1Load.Font = $UITheme.ButtonFont
    $pnlT1Search.Controls.Add($btnT1Load)

    $lblFilter = New-Object System.Windows.Forms.Label; $lblFilter.Text = "Filter:"; $lblFilter.Location = "10, 52"; $lblFilter.AutoSize = $true; $lblFilter.Font = $UITheme.LabelFont; $pnlT1Search.Controls.Add($lblFilter)
    $txtGroupFilter = New-Object System.Windows.Forms.TextBox; $txtGroupFilter.Location = "55, 49"; $txtGroupFilter.Size = "215, 25"; $pnlT1Search.Controls.Add($txtGroupFilter)
    $btnSelectAll = New-Object System.Windows.Forms.Button; $btnSelectAll.Text = "Alle wählen"; $btnSelectAll.Location = "280, 48"; $btnSelectAll.Size = "90, 27"; $pnlT1Search.Controls.Add($btnSelectAll)
    $btnDeselectAll = New-Object System.Windows.Forms.Button; $btnDeselectAll.Text = "Keine"; $btnDeselectAll.Location = "375, 48"; $btnDeselectAll.Size = "70, 27"; $pnlT1Search.Controls.Add($btnDeselectAll)

    $gridT1Groups = New-Object System.Windows.Forms.DataGridView
    $gridT1Groups.Dock = [System.Windows.Forms.DockStyle]::Fill
    $gridT1Groups.AllowUserToAddRows = $false
    $gridT1Groups.AllowUserToDeleteRows = $false
    $gridT1Groups.RowHeadersVisible = $false
    $gridT1Groups.SelectionMode = [System.Windows.Forms.DataGridViewSelectionMode]::FullRowSelect
    $gridT1Groups.BackgroundColor = [System.Drawing.Color]::White
    $gridT1Groups.Font = $UITheme.GridFont
    $gridT1Groups.EnableHeadersVisualStyles = $false
    $gridT1Groups.ColumnHeadersDefaultCellStyle.BackColor = $UITheme.HeaderBack
    $gridT1Groups.ColumnHeadersDefaultCellStyle.Font = $UITheme.GridHeaderFont
    $gridT1Groups.ColumnHeadersHeight = 30

    $colCheck = New-Object System.Windows.Forms.DataGridViewCheckBoxColumn; $colCheck.Name = "ColCheck"; $colCheck.HeaderText = "Übernehmen"; $colCheck.Width = 90
    [void]$gridT1Groups.Columns.Add($colCheck)
    $colName = New-Object System.Windows.Forms.DataGridViewTextBoxColumn; $colName.Name = "ColName"; $colName.HeaderText = "Gruppenname"; $colName.Width = 240; $colName.ReadOnly = $true
    [void]$gridT1Groups.Columns.Add($colName)
    $colDesc = New-Object System.Windows.Forms.DataGridViewTextBoxColumn; $colDesc.Name = "ColDesc"; $colDesc.HeaderText = "Beschreibung (Description)"; $colDesc.AutoSizeMode = [System.Windows.Forms.DataGridViewAutoSizeColumnMode]::Fill; $colDesc.ReadOnly = $true
    [void]$gridT1Groups.Columns.Add($colDesc)

    $grpT1Left.Controls.Add($gridT1Groups)
    $gridT1Groups.BringToFront()

    # Rechts: Attribute
    $grpT1Right = New-Object System.Windows.Forms.GroupBox
    $grpT1Right.Text = "Neuer Benutzer (Attribute)"
    $grpT1Right.Dock = [System.Windows.Forms.DockStyle]::Fill
    $grpT1Right.Font = $UITheme.SectionFont
    $splitT1.Panel2.Controls.Add($grpT1Right)

    $tblT1 = New-Object System.Windows.Forms.TableLayoutPanel
    $tblT1.Dock = [System.Windows.Forms.DockStyle]::Top
    $tblT1.Height = 260
    $tblT1.ColumnCount = 2; $tblT1.RowCount = 5
    $tblT1.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Absolute, 130)))
    $tblT1.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 100)))

    for ($i = 0; $i -lt 5; $i++) {
        $tblT1.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 46)))
    }
    $grpT1Right.Controls.Add($tblT1)

    $t1TxtFirst = New-Object System.Windows.Forms.TextBox; Add-FormInputRow $tblT1 0 "Vorname:" $t1TxtFirst
    $t1TxtLast  = New-Object System.Windows.Forms.TextBox; Add-FormInputRow $tblT1 1 "Nachname:" $t1TxtLast
    $t1TxtSam   = New-Object System.Windows.Forms.TextBox; Add-FormInputRow $tblT1 2 "Anmeldename:" $t1TxtSam
    $t1TxtPwd   = New-Object System.Windows.Forms.TextBox; $t1TxtPwd.PasswordChar = "*"; Add-FormInputRow $tblT1 3 "Kennwort:" $t1TxtPwd
    
    $t1CmbOU = New-Object System.Windows.Forms.ComboBox
    $t1CmbOU.AutoCompleteMode = [System.Windows.Forms.AutoCompleteMode]::SuggestAppend
    $t1CmbOU.AutoCompleteSource = [System.Windows.Forms.AutoCompleteSource]::ListItems
    foreach ($o in $allOUs) { [void]$t1CmbOU.Items.Add($o) }
    if ($t1CmbOU.Items.Count -gt 0) { $t1CmbOU.SelectedIndex = 0 }
    Add-FormInputRow $tblT1 4 "Ziel-OU:" $t1CmbOU

    $t1TxtLast.Add_TextChanged({
        if ($t1TxtLast.Text.Trim() -and -not $t1TxtSam.Text.Trim()) {
            $fInit = if ($t1TxtFirst.Text.Trim().Length -gt 0) { $t1TxtFirst.Text.Trim().Substring(0,1).ToLower() } else { "" }
            $t1TxtSam.Text = "$fInit$($t1TxtLast.Text.Trim().ToLower())"
        }
    })

    $script:LoadedT1Groups = [System.Collections.Generic.List[PSCustomObject]]::new()

    $loadT1GroupsAction = {
        $gridT1Groups.Rows.Clear()
        $script:LoadedT1Groups.Clear()
        $term = $txtT1Source.Text.Trim()
        if (-not $term) { return }

        try {
            $srcUser = Get-ADUser -Filter "sAMAccountName -eq '$term' -or Name -eq '$term'" -Properties MemberOf, DistinguishedName -ErrorAction Stop
            if ($srcUser) {
                $t1CmbOU.Text = ($srcUser.DistinguishedName -replace '^CN=.*?(?<!\\),','')

                foreach ($grpDN in $srcUser.MemberOf) {
                    $grpObj = Get-ADGroup -Identity $grpDN -Properties Description -ErrorAction SilentlyContinue
                    $script:LoadedT1Groups.Add([PSCustomObject]@{
                        Check = $true
                        Name  = $grpObj.Name
                        Desc  = $grpObj.Description
                    })
                }
                & $renderT1Groups
            }
        } catch {
            [System.Windows.Forms.MessageBox]::Show("Quell-Benutzer '$term' nicht gefunden.", "Hinweis", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
        }
    }

    $renderT1Groups = {
        $filter = $txtGroupFilter.Text.Trim()
        $gridT1Groups.Rows.Clear()
        foreach ($g in $script:LoadedT1Groups) {
            if (-not $filter -or $g.Name -like "*$filter*" -or $g.Desc -like "*$filter*") {
                [void]$gridT1Groups.Rows.Add($g.Check, $g.Name, $g.Desc)
            }
        }
    }

    $btnT1Load.Add_Click($loadT1GroupsAction)
    $txtT1Source.Add_KeyDown({ if ($_.KeyCode -eq [System.Windows.Forms.Keys]::Enter) { $_.SuppressKeyPress = $true; & $loadT1GroupsAction } })
    $txtGroupFilter.Add_TextChanged($renderT1Groups)

    $btnSelectAll.Add_Click({
        foreach ($r in $gridT1Groups.Rows) { $r.Cells["ColCheck"].Value = $true }
        foreach ($g in $script:LoadedT1Groups) { $g.Check = $true }
    })
    $btnDeselectAll.Add_Click({
        foreach ($r in $gridT1Groups.Rows) { $r.Cells["ColCheck"].Value = $false }
        foreach ($g in $script:LoadedT1Groups) { $g.Check = $false }
    })

    $gridT1Groups.Add_CellValueChanged({
        param($s, $e)
        if ($e.RowIndex -ge 0 -and $e.ColumnIndex -eq 0) {
            $rowName = [string]$gridT1Groups.Rows[$e.RowIndex].Cells["ColName"].Value
            $val = [bool]$gridT1Groups.Rows[$e.RowIndex].Cells["ColCheck"].Value
            $match = $script:LoadedT1Groups | Where-Object { $_.Name -eq $rowName }
            if ($match) { $match.Check = $val }
        }
    })

    # ==========================================================================
    # BUILDER FÜR TABS 2, 3 & 4 (EIGENSTÄNDIGE DATENKAPSELUNG)
    # ==========================================================================
    function Build-AdminProvisioningTab {
        param(
            [System.Windows.Forms.TabPage]$ParentTab,
            [string]$BoxTitle,
            [string]$DefaultPrefix,
            [string[]]$PrefixOptions,
            [string]$RoleTitle,
            [hashtable[]]$StandardGroups
        )

        $ParentTab.Padding = New-Object System.Windows.Forms.Padding(10)

        $box = New-Object System.Windows.Forms.GroupBox
        $box.Text = $BoxTitle
        $box.Dock = [System.Windows.Forms.DockStyle]::Fill
        $box.Font = $UITheme.SectionFont
        $ParentTab.Controls.Add($box)

        $split = New-Object System.Windows.Forms.SplitContainer
        $split.Dock = [System.Windows.Forms.DockStyle]::Fill
        $split.SplitterDistance = 780
        $split.SplitterWidth = 6
        $box.Controls.Add($split)

        $tbl = New-Object System.Windows.Forms.TableLayoutPanel
        $tbl.Dock = [System.Windows.Forms.DockStyle]::Fill
        $tbl.ColumnCount = 2
        $tbl.RowCount = 11
        $tbl.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Absolute, 220)))
        $tbl.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 100)))

        for ($i = 0; $i -lt 11; $i++) {
            $tbl.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 44)))
        }
        $split.Panel1.Controls.Add($tbl)

        $tCmbPrefix  = New-Object System.Windows.Forms.ComboBox; $tCmbPrefix.Font = $UITheme.InputFont
        [void]$tCmbPrefix.Items.AddRange($PrefixOptions)
        $tCmbPrefix.Text = $DefaultPrefix

        $tTxtSource  = New-Object System.Windows.Forms.TextBox; $tTxtSource.Text = "$DefaultPrefix-"
        $tTxtFirst   = New-Object System.Windows.Forms.TextBox
        $tTxtLast    = New-Object System.Windows.Forms.TextBox

        $tCmbOU      = New-Object System.Windows.Forms.ComboBox; $tCmbOU.Font = $UITheme.InputFont
        $tCmbOU.AutoCompleteMode = [System.Windows.Forms.AutoCompleteMode]::SuggestAppend
        $tCmbOU.AutoCompleteSource = [System.Windows.Forms.AutoCompleteSource]::ListItems
        foreach ($ou in $allOUs) { [void]$tCmbOU.Items.Add($ou) }
        if ($tCmbOU.Items.Count -gt 0) { $tCmbOU.SelectedIndex = 0 }

        $tTxtSam     = New-Object System.Windows.Forms.TextBox; $tTxtSam.ReadOnly = $true; $tTxtSam.BackColor = [System.Drawing.Color]::WhiteSmoke
        $tTxtGiven   = New-Object System.Windows.Forms.TextBox; $tTxtGiven.Text = $DefaultPrefix
        $tTxtDisp    = New-Object System.Windows.Forms.TextBox; $tTxtDisp.ReadOnly = $true; $tTxtDisp.BackColor = [System.Drawing.Color]::WhiteSmoke
        $tTxtDesc    = New-Object System.Windows.Forms.TextBox
        $tTxtPwd     = New-Object System.Windows.Forms.TextBox; $tTxtPwd.PasswordChar = "*"

        Add-FormInputRow $tbl 0 "Präfix / Vorname:" $tCmbPrefix
        Add-FormInputRow $tbl 1 "Aus Vorlage/User kopieren:" $tTxtSource
        Add-FormInputRow $tbl 2 "Ziel-OU (Auswahl/Pfad):" $tCmbOU
        Add-FormInputRow $tbl 3 "Echter Vorname:" $tTxtFirst
        Add-FormInputRow $tbl 4 "Nachname:" $tTxtLast

        $lblHeader = New-Object System.Windows.Forms.Label
        $lblHeader.Text = "AD-Attribute (Automatisch lt. Standard)"
        $lblHeader.Font = $UITheme.TitleFont
        $lblHeader.ForeColor = $UITheme.AccentColor
        $lblHeader.Dock = [System.Windows.Forms.DockStyle]::Fill
        $lblHeader.TextAlign = [System.Drawing.ContentAlignment]::BottomLeft
        $tbl.SetColumnSpan($lblHeader, 2)
        $tbl.Controls.Add($lblHeader, 0, 5)

        Add-FormInputRow $tbl 6 "Konto / User (SAM):" $tTxtSam
        Add-FormInputRow $tbl 7 "Vorname (AD-Attribut):" $tTxtGiven
        Add-FormInputRow $tbl 8 "Anzeigename:" $tTxtDisp
        Add-FormInputRow $tbl 9 "Beschreibung:" $tTxtDesc
        Add-FormInputRow $tbl 10 "Kennwort:" $tTxtPwd

        # Rechte Seite: Gruppen
        $pnlRight = New-Object System.Windows.Forms.Panel
        $pnlRight.Dock = [System.Windows.Forms.DockStyle]::Fill
        $pnlRight.Padding = New-Object System.Windows.Forms.Padding(15, 10, 15, 12)
        $split.Panel2.Controls.Add($pnlRight)

        $lblGrpTitle = New-Object System.Windows.Forms.Label
        $lblGrpTitle.Text = "Mitglied von (Gruppen-Logik):"
        $lblGrpTitle.Font = $UITheme.SectionFont
        $lblGrpTitle.ForeColor = $UITheme.AccentColor
        $lblGrpTitle.Dock = [System.Windows.Forms.DockStyle]::Top
        $lblGrpTitle.Height = 35
        $pnlRight.Controls.Add($lblGrpTitle)

        $tChkList = New-Object System.Windows.Forms.CheckedListBox
        $tChkList.Dock = [System.Windows.Forms.DockStyle]::Fill
        $tChkList.Font = $UITheme.InputFont
        $tChkList.CheckOnClick = $true
        $pnlRight.Controls.Add($tChkList)
        $tChkList.BringToFront()

        foreach ($g in $StandardGroups) { [void]$tChkList.Items.Add($g.Name, $g.Checked) }

        $tabData = [PSCustomObject]@{
            PrefixBox = $tCmbPrefix
            RealFirst = $tTxtFirst
            RealLast  = $tTxtLast
            TargetOU  = $tCmbOU
            SamBox    = $tTxtSam
            GivenBox  = $tTxtGiven
            DispBox   = $tTxtDisp
            DescBox   = $tTxtDesc
            PwdBox    = $tTxtPwd
            GroupList = $tChkList
            RoleTitle = $RoleTitle
        }

        $syncAction = {
            param($data)
            $p = $data.PrefixBox.Text.Trim()
            $l = $data.RealLast.Text.Trim()
            $f = $data.RealFirst.Text.Trim()
            $data.GivenBox.Text = $p

            if ($l) {
                $pDisplay = if ($p.Length -gt 1) { $p.Substring(0,1).ToUpper() + $p.Substring(1) } else { $p.ToUpper() }
                if ($p.ToLower() -eq "dadm") { $pDisplay = "DAdm" }
                if ($p.ToLower() -eq "ladm") { $pDisplay = "LAdm" }

                $data.SamBox.Text  = "$pDisplay-$l"
                $data.DispBox.Text = "$pDisplay $l"
                $data.DescBox.Text = "$($data.RoleTitle) $f $l".Trim()
            } else {
                $data.SamBox.Text  = ""
                $data.DispBox.Text = ""
                $data.DescBox.Text = ""
            }
        }

        $tTxtFirst.Add_TextChanged({ & $syncAction $tabData })
        $tTxtLast.Add_TextChanged({ & $syncAction $tabData })
        $tCmbPrefix.Add_TextChanged({ & $syncAction $tabData })

        $tTxtSource.Add_KeyDown({
            if ($_.KeyCode -eq [System.Windows.Forms.Keys]::Enter) {
                $_.SuppressKeyPress = $true
                $term = $tTxtSource.Text.Trim()
                try {
                    $src = Get-ADUser -Filter "sAMAccountName -eq '$term' -or Name -eq '$term'" -Properties MemberOf, DistinguishedName -ErrorAction Stop
                    if ($src) {
                        $tCmbOU.Text = ($src.DistinguishedName -replace '^CN=.*?(?<!\\),','')
                        for ($k = 0; $k -lt $tChkList.Items.Count; $k++) {
                            $item = $tChkList.Items[$k].ToString()
                            $has = $src.MemberOf | Where-Object { $_ -like "CN=$item,*" }
                            $tChkList.SetItemChecked($k, ($null -ne $has -or $item -eq "Domänen-Benutzer"))
                        }
                        [System.Windows.Forms.MessageBox]::Show("Vorlage '$term' eingelesen.", "Vorlage", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
                    }
                } catch {
                    [System.Windows.Forms.MessageBox]::Show("Vorlage '$term' nicht gefunden.", "Hinweis", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
                }
            }
        })

        return $tabData
    }

    # ==========================================================================
    # REGISTER 2, 3 & 4 INITIALISIEREN
    # ==========================================================================
    $tab2 = New-Object System.Windows.Forms.TabPage; $tab2.Text = "2. Install-User"; $tabs.Controls.Add($tab2)
    $ctrlsT2 = Build-AdminProvisioningTab -ParentTab $tab2 -BoxTitle "Install-User Account-Standards" -DefaultPrefix "install" -PrefixOptions @("install", "svc", "setup") -RoleTitle "Installation & Service" -StandardGroups @(@{ Name = "Domänen-Benutzer"; Checked = $true })

    $tab3 = New-Object System.Windows.Forms.TabPage; $tab3.Text = "3. ladm-User"; $tabs.Controls.Add($tab3)
    $ctrlsT3 = Build-AdminProvisioningTab -ParentTab $tab3 -BoxTitle "Local Admin Standards (Tier-1 / Member Server)" -DefaultPrefix "ladm" -PrefixOptions @("ladm", "adm", "l-admin") -RoleTitle "Local Administrator" -StandardGroups @(@{ Name = "Domänen-Benutzer"; Checked = $true }, @{ Name = "ADS-FGPP-LAdm"; Checked = $true })

    $tab4 = New-Object System.Windows.Forms.TabPage; $tab4.Text = "4. Domain Admin"; $tabs.Controls.Add($tab4)
    $ctrlsT4 = Build-AdminProvisioningTab -ParentTab $tab4 -BoxTitle "Domain Admin Standards (Tier-0 Richtlinie lt. Vorlage)" -DefaultPrefix "dadm" -PrefixOptions @("dadm", "ladm", "adm", "da", "admin") -RoleTitle "Domain Administrator" -StandardGroups @(
        @{ Name = "ADS-FGPP-DAdm";   Checked = $true },
        @{ Name = "Domänen-Admins";   Checked = $true },
        @{ Name = "Domänen-Benutzer"; Checked = $true },
        @{ Name = "Protected Users"; Checked = $true }
    )

    # ==========================================================================
    # BEFEHLSLEISTE & ANLEGEN
    # ==========================================================================
    $pnlBottom = New-Object System.Windows.Forms.Panel
    $pnlBottom.Dock = [System.Windows.Forms.DockStyle]::Bottom
    $pnlBottom.Height = 68
    $pnlBottom.BackColor = [System.Drawing.Color]::FromArgb(238, 242, 246)
    $pnlBottom.Padding = New-Object System.Windows.Forms.Padding(15, 12, 15, 12)
    $form.Controls.Add($pnlBottom)

    $btnCreate = New-Object System.Windows.Forms.Button
    $btnCreate.Text = "Konto im Active Directory erstellen"
    $btnCreate.Dock = [System.Windows.Forms.DockStyle]::Right
    $btnCreate.Width = 350
    $btnCreate.BackColor = [System.Drawing.Color]::FromArgb(16, 124, 65)
    $btnCreate.ForeColor = [System.Drawing.Color]::White
    $btnCreate.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $btnCreate.Font = $UITheme.ButtonFont
    $pnlBottom.Controls.Add($btnCreate)

    $btnCreate.Add_Click({
        try {
            $curIndex = $tabs.SelectedIndex
            $targetGroups = [System.Collections.Generic.List[string]]::new()

            if ($curIndex -eq 0) {
                $sam      = $t1TxtSam.Text.Trim()
                $given    = $t1TxtFirst.Text.Trim()
                $sn       = $t1TxtLast.Text.Trim()
                $display  = "$given $sn".Trim()
                $desc     = "Standardbenutzer"
                $pwdPlain = $t1TxtPwd.Text
                $targetOU = $t1CmbOU.Text.Trim()

                foreach ($r in $gridT1Groups.Rows) {
                    if ([bool]$r.Cells["ColCheck"].Value -eq $true) {
                        $targetGroups.Add([string]$r.Cells["ColName"].Value)
                    }
                }
            }
            else {
                $c = switch ($curIndex) {
                    1 { $ctrlsT2 }
                    2 { $ctrlsT3 }
                    3 { $ctrlsT4 }
                }
                $sam      = $c.SamBox.Text.Trim()
                $given    = $c.GivenBox.Text.Trim()
                $sn       = $c.RealLast.Text.Trim()
                $display  = $c.DispBox.Text.Trim()
                $desc     = $c.DescBox.Text.Trim()
                $pwdPlain = $c.PwdBox.Text
                $targetOU = $c.TargetOU.Text.Trim()

                foreach ($item in $c.GroupList.CheckedItems) {
                    $targetGroups.Add($item.ToString())
                }
            }

            if ([string]::IsNullOrWhiteSpace($sn) -or [string]::IsNullOrWhiteSpace($pwdPlain)) {
                [System.Windows.Forms.MessageBox]::Show("Bitte Nachname und Kennwort eingeben.", "Eingabe fehlt", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
                return
            }
            if ([string]::IsNullOrWhiteSpace($targetOU)) {
                [System.Windows.Forms.MessageBox]::Show("Bitte eine Ziel-OU auswählen.", "OU fehlt", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
                return
            }

            $exists = Get-ADUser -Filter "sAMAccountName -eq '$sam'" -ErrorAction SilentlyContinue
            if ($exists) {
                [System.Windows.Forms.MessageBox]::Show("Ein Konto mit dem Anmeldenamen '$sam' existiert bereits!", "Duplikat", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
                return
            }

            $secPassword = ConvertTo-SecureString $pwdPlain -AsPlainText -Force

            $userParams = @{
                Name                  = $display
                SamAccountName        = $sam
                UserPrincipalName     = "$sam@$upnSuffix"
                DisplayName           = $display
                Surname               = $sn
                GivenName             = $given
                Description           = $desc
                Path                  = $targetOU
                AccountPassword       = $secPassword
                Enabled               = $true
                PasswordNeverExpires  = $false
                ErrorAction           = "Stop"
            }

            New-ADUser @userParams

            $assigned = [System.Collections.Generic.List[string]]::new()
            $failed   = [System.Collections.Generic.List[string]]::new()

            foreach ($grp in $targetGroups) {
                if ($grp -eq "Domänen-Benutzer") {
                    $assigned.Add("$grp (Primär)")
                    continue
                }
                try {
                    Add-ADGroupMember -Identity $grp -Members $sam -ErrorAction Stop
                    $assigned.Add($grp)
                } catch {
                    $failed.Add("$grp ($($_.Exception.Message))")
                }
            }

            $resMsg = "Benutzer '$sam' erfolgreich im AD angelegt!`r`n`r`nZiel-OU: $targetOU`r`n`r`nZugewiesene Gruppen:`r`n - " + ($assigned -join "`r`n - ")
            if ($failed.Count -gt 0) {
                $resMsg += "`r`n`r`nFehler bei Gruppen:`r`n - " + ($failed -join "`r`n - ")
                [System.Windows.Forms.MessageBox]::Show($resMsg, "Angelegt (mit Warnungen)", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
            } else {
                [System.Windows.Forms.MessageBox]::Show($resMsg, "Erfolg", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
            }
        }
        catch {
            [System.Windows.Forms.MessageBox]::Show("Fehler beim Erstellen:`r`n$($_.Exception.Message)", "AD-Fehler", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
        }
    })

    # Dialog-Aufruf mit sauberem Cleanup für die PowerShell ISE
    try {
        [void]$form.ShowDialog()
    } finally {
        if ($form) { $form.Dispose() }
        if ($script:LoadedT1Groups) { $script:LoadedT1Groups.Clear() }
        [System.GC]::Collect()
        [System.GC]::WaitForPendingFinalizers()
    }
}

Show-ADUserManagementSuite
