Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# --- Hauptfenster ---
$form = New-Object System.Windows.Forms.Form
$form.Text = "Exchange Autodiscover & SSL-Zertifikat Analyse"
$form.Size = New-Object System.Drawing.Size(960, 720)
$form.StartPosition = "CenterScreen"
$form.MinimumSize = New-Object System.Drawing.Size(800, 550)

# Eingabe-Label
$lblDomains = New-Object System.Windows.Forms.Label
$lblDomains.Location = New-Object System.Drawing.Point(15, 10)
$lblDomains.Size = New-Object System.Drawing.Size(260, 20)
$lblDomains.Text = "Domains (eine pro Zeile):"
$form.Controls.Add($lblDomains)

# Textbox für Domains
$txtDomains = New-Object System.Windows.Forms.TextBox
$txtDomains.Location = New-Object System.Drawing.Point(15, 30)
$txtDomains.Size = New-Object System.Drawing.Size(260, 320)
$txtDomains.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Left
$txtDomains.Multiline = $true
$txtDomains.ScrollBars = [System.Windows.Forms.ScrollBars]::Vertical
$form.Controls.Add($txtDomains)

# Button: Domains auslesen
$btnDetect = New-Object System.Windows.Forms.Button
$btnDetect.Location = New-Object System.Drawing.Point(15, 360)
$btnDetect.Size = New-Object System.Drawing.Size(125, 35)
$btnDetect.Text = "Domains auslesen"
$form.Controls.Add($btnDetect)

# Button: Prüfung starten
$btnStart = New-Object System.Windows.Forms.Button
$btnStart.Location = New-Object System.Drawing.Point(150, 360)
$btnStart.Size = New-Object System.Drawing.Size(125, 35)
$btnStart.Text = "Prüfung starten"
$btnStart.BackColor = [System.Drawing.Color]::LightSteelBlue
$form.Controls.Add($btnStart)

# DataGridView
$grid = New-Object System.Windows.Forms.DataGridView
$grid.Location = New-Object System.Drawing.Point(290, 30)
$grid.Size = New-Object System.Drawing.Size(640, 365)
$grid.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right
$grid.ReadOnly = $true
$grid.AllowUserToAddRows = $false
$grid.RowHeadersVisible = $false
$grid.SelectionMode = [System.Windows.Forms.DataGridViewSelectionMode]::FullRowSelect
$grid.MultiSelect = $false
$grid.AutoSizeColumnsMode = [System.Windows.Forms.DataGridViewAutoSizeColumnsMode]::Fill
$form.Controls.Add($grid)

[void]$grid.Columns.Add("Domain", "Domain")
[void]$grid.Columns.Add("DNS", "DNS (CNAME/SRV)")
[void]$grid.Columns.Add("CertMatch", "Im Zertifikat (SAN)?")
[void]$grid.Columns.Add("Status", "HTTPS Status")

$grid.Columns["Domain"].FillWeight = 24
$grid.Columns["DNS"].FillWeight = 26
$grid.Columns["CertMatch"].FillWeight = 25
$grid.Columns["Status"].FillWeight = 25

# Detail-Box
$lblDetail = New-Object System.Windows.Forms.Label
$lblDetail.Location = New-Object System.Drawing.Point(15, 410)
$lblDetail.Size = New-Object System.Drawing.Size(500, 20)
$lblDetail.Text = "Zertifikats-Details der markierten Domain:"
$form.Controls.Add($lblDetail)

$txtDetails = New-Object System.Windows.Forms.TextBox
$txtDetails.Location = New-Object System.Drawing.Point(15, 435)
$txtDetails.Size = New-Object System.Drawing.Size(915, 205)
$txtDetails.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right
$txtDetails.Multiline = $true
$txtDetails.ReadOnly = $true
$txtDetails.ScrollBars = [System.Windows.Forms.ScrollBars]::Vertical
$txtDetails.BackColor = [System.Drawing.Color]::WhiteSmoke
$txtDetails.Font = New-Object System.Drawing.Font("Consolas", 9)
$form.Controls.Add($txtDetails)

# Statusleiste
$statusStrip = New-Object System.Windows.Forms.StatusStrip
$lblStatus = New-Object System.Windows.Forms.ToolStripStatusLabel
$lblStatus.Text = "Bereit."
[void]$statusStrip.Items.Add($lblStatus)
$form.Controls.Add($statusStrip)

$script:DomainDetails = @{}

# --- Funktion: Domains ermitteln ---
$DetectDomains = {
    $lblStatus.Text = "Lese Domains aus Umgebung..."
    $form.Refresh()
    $found = [System.Collections.Generic.HashSet[string]]::new()

    if (Get-Command Get-AcceptedDomain -ErrorAction SilentlyContinue) {
        try { Get-AcceptedDomain | ForEach-Object { $found.Add($_.DomainName.ToString().ToLower()) } } catch {}
    }
    if ($found.Count -eq 0 -and (Get-Command Get-ADForest -ErrorAction SilentlyContinue)) {
        try {
            $f = Get-ADForest
            $f.UPNSuffixes | ForEach-Object { if ($_) { $found.Add($_.ToLower()) } }
            $f.Domains | ForEach-Object { if ($_) { $found.Add($_.ToLower()) } }
        } catch {}
    }
    if ($found.Count -eq 0) {
        $loc = [System.Net.NetworkInformation.IPGlobalProperties]::GetIPGlobalProperties().DomainName
        if ($loc) { $found.Add($loc.ToLower()) }
    }

    if ($found.Count -gt 0) {
        $txtDomains.Text = ($found | Sort-Object) -join "`r`n"
        $lblStatus.Text = "$($found.Count) Domain(s) gefunden."
    } else {
        $lblStatus.Text = "Keine Domains automatisch ermittelt. Bitte manuell eingeben."
    }
}

$btnDetect.Add_Click({ & $DetectDomains })

# --- Prüfung ausführen ---
$btnStart.Add_Click({
    $domains = $txtDomains.Lines | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" }
    if ($domains.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show("Bitte mindestens eine Domain angeben.", "Hinweis", 0, 48)
        return
    }

    $btnStart.Enabled = $false
    $btnDetect.Enabled = $false
    $grid.Rows.Clear()
    $script:DomainDetails.Clear()
    $txtDetails.Clear()

    foreach ($d in $domains) {
        $lblStatus.Text = "Prüfe $d..."
        $form.Refresh()

        $targetHost = "autodiscover.$d"
        $dnsInfo = "-"
        $certMatch = "Nicht prüfbar"
        $httpsStatus = ""
        $isOk = $false
        $detailLog = @()

        # 1. DNS CNAME, SRV und A prüfen
        $cname = Resolve-DnsName -Name $targetHost -Type CNAME -ErrorAction SilentlyContinue | Select-Object -ExpandProperty NameHost -First 1
        $srv = Resolve-DnsName -Name "_autodiscover._tcp.$d" -Type SRV -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Target -First 1

        $connectHost = $targetHost
        if ($cname) { 
            $dnsInfo = "CNAME: $cname"
            $connectHost = $cname # Bei CNAME auf das tatsächliche Ziel verbinden
        } elseif ($srv) { 
            $dnsInfo = "SRV: $srv"
            $connectHost = $srv
        } else {
            $aRecord = Resolve-DnsName -Name $targetHost -Type A -ErrorAction SilentlyContinue | Select-Object -ExpandProperty IPAddress -First 1
            if ($aRecord) { 
                $dnsInfo = "A-Record: $aRecord" 
            } else { 
                $dnsInfo = "Kein DNS-Eintrag"
                $connectHost = $null
            }
        }

        # 2. Zertifikat sauber auslesen (OHNE ConnectAsync / OHNE .Wait())
        if (-not $connectHost) {
            $certMatch = "Kein DNS-Eintrag"
            $detailLog += "Host '$targetHost' existiert im DNS nicht."
        } else {
            $tcpClient = $null
            $sslStream = $null
            try {
                $tcpClient = New-Object System.Net.Sockets.TcpClient
                # Klassisches BeginConnect mit Timeout über WaitOne
                $asyncResult = $tcpClient.BeginConnect($connectHost, 443, $null, $null)
                $connectedInTime = $asyncResult.AsyncWaitHandle.WaitOne(3000, $false)

                if ($connectedInTime -and $tcpClient.Connected) {
                    $tcpClient.EndConnect($asyncResult)
                    
                    $sslCallback = { $true }
                    $sslStream = New-Object System.Net.Security.SslStream($tcpClient.GetStream(), $false, $sslCallback)
                    # SNI-Handshake durchführen
                    $sslStream.AuthenticateAsClient($targetHost)
                    
                    $remoteCert = $sslStream.RemoteCertificate
                    if ($remoteCert) {
                        $cert2 = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($remoteCert)
                        $cnName = $cert2.GetNameInfo([System.Security.Cryptography.X509Certificates.X509NameType]::SimpleName, $false)
                        
                        $sanList = @()
                        $sanExt = $cert2.Extensions | Where-Object { $_.Oid.FriendlyName -eq "Alternativer Antragstellername" -or $_.Oid.Value -eq "2.5.29.17" }
                        if ($sanExt) {
                            $sanList = $sanExt.Format($true) -split "`r`n" | ForEach-Object { $_.Trim() } | Where-Object { $_ -match "^DNS(-Name)?=" } | ForEach-Object { $_ -replace "^DNS(-Name)?=", "" }
                        }

                        # Wildcard-Prüfung (*.domain.de)
                        $domainParts = $d.Split('.')
                        $wildcard = if ($domainParts.Count -ge 2) { "*." + ($domainParts[-2..-1] -join '.') } else { "*.$d" }

                        if ($sanList -contains $targetHost -or $cnName -eq $targetHost -or $sanList -contains $wildcard) {
                            $certMatch = "Gültig (Enthalten)"
                        } else {
                            $certMatch = "FEHLT im Zertifikat"
                        }

                        $detailLog += "Geprüfter Host: $targetHost"
                        $detailLog += "Verbunden mit Host: $connectHost"
                        $detailLog += "Hauptname im Zertifikat (CN): $cnName"
                        $detailLog += "Gültig bis: $($cert2.GetExpirationDateString())"
                        $detailLog += "Erlaubte SAN-Namen ($($sanList.Count)):`r`n" + (($sanList | ForEach-Object { "  - $_" }) -join "`r`n")
                    }
                } else {
                    $certMatch = "Port 443 Timeout"
                    $detailLog += "Verbindung zu $connectHost Port 443 reagiert nicht innerhalb von 3 Sekunden."
                }
            } catch {
                $certMatch = "Verbindungsfehler"
                $detailLog += "Fehler beim Zertifikatsabruf für $targetHost via $connectHost`r`nUrsache: $($_.Exception.Message)"
            } finally {
                if ($sslStream) { $sslStream.Dispose() }
                if ($tcpClient) { $tcpClient.Dispose() }
            }
        }

        # 3. HTTPS Endpunkt testen
        $url = "https://$targetHost/autodiscover/autodiscover.xml"
        try {
            $req = Invoke-WebRequest -Uri $url -Method Get -SkipCertificateCheck:$false -TimeoutSec 3 -ErrorAction Stop
            $httpsStatus = "OK ($($req.StatusCode))"
            $isOk = $true
        } catch {
            if ($_.Exception.Response.StatusCode.value__ -eq 401) {
                $httpsStatus = "OK (401 Auth)"
                $isOk = $true
            } elseif ($_.Exception.Message -match "SSL|Trust|Zertifikat|Certificate") {
                $httpsStatus = "SSL-Fehler"
            } elseif ($_.Exception.Message -match "Host|Name|Aufgelöst") {
                $httpsStatus = "DNS-Fehler"
            } else {
                $httpsStatus = "Nicht erreichbar"
            }
        }

        # Details sichern
        $script:DomainDetails[$d] = ($detailLog -join "`r`n")

        # In Tabelle schreiben
        $rowIndex = $grid.Rows.Add($d, $dnsInfo, $certMatch, $httpsStatus)
        if ($rowIndex -ge 0) {
            $certCell = $grid.Rows[$rowIndex].Cells["CertMatch"]
            $statusCell = $grid.Rows[$rowIndex].Cells["Status"]
            
            if ($certMatch -eq "Gültig (Enthalten)") {
                $certCell.Style.ForeColor = [System.Drawing.Color]::DarkGreen
            } else {
                $certCell.Style.ForeColor = [System.Drawing.Color]::DarkRed
            }

            if ($isOk) {
                $statusCell.Style.ForeColor = [System.Drawing.Color]::DarkGreen
            } else {
                $statusCell.Style.ForeColor = [System.Drawing.Color]::DarkRed
            }
        }
    }

    $lblStatus.Text = "Prüfung abgeschlossen ($($domains.Count) Domains)."
    $btnStart.Enabled = $true
    $btnDetect.Enabled = $true
    
    if ($grid.Rows.Count -gt 0) {
        $grid.Rows[0].Selected = $true
        $selectedDom = $grid.Rows[0].Cells["Domain"].Value
        $txtDetails.Text = $script:DomainDetails[$selectedDom]
    }
})

# Klick-Event für Detail-Aktualisierung
$grid.Add_SelectionChanged({
    if ($grid.SelectedRows.Count -gt 0) {
        $selDomain = $grid.SelectedRows[0].Cells["Domain"].Value
        if ($selDomain -and $script:DomainDetails.ContainsKey($selDomain)) {
            $txtDetails.Text = $script:DomainDetails[$selDomain]
        }
    }
})

$form.Add_Shown({ & $DetectDomains })
[void]$form.ShowDialog()
