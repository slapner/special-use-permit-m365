#Requires -Version 7.4
<#
.SYNOPSIS
    Provisions the Special Use Permit (SUP) SharePoint site, lists, libraries, groups, views and seed data.

.DESCRIPTION
    *** UNTESTED AGAINST A LIVE TENANT — RUN IN A TEST TENANT / TEST SITE ALIAS FIRST. ***

    Source of truth for every name: spec/data-model.md. Internal column names are fixed at creation,
    so do not edit them here without changing the spec, the flows and the app.

    Requirements
      - PowerShell 7.4+ and PnP.PowerShell 3.x (checked against 3.5.0; 2.x needs PS 7.2+ and should also work):  Install-Module PnP.PowerShell -Scope CurrentUser
      - The account running this must be a SharePoint Administrator (site creation is done through the
        tenant admin endpoint).
      - Your OWN Entra ID app registration (-ClientId). PnP's shared multi-tenant "PnP Management Shell"
        app was retired in September 2024, so every tenant must register its own app once:
            Register-PnPEntraIDAppForInteractiveLogin -ApplicationName "SUP Provisioning" -Tenant <tenant>.onmicrosoft.com
        (Admin consent is required for the delegated SharePoint permissions it requests.)
        Government clouds: add -AzureEnvironment USGovernment (GCC), USGovernmentHigh (GCC High) or
        USGovernmentDoD (DoD) to that command AND pass the same value to this script. GCC tenants use
        .sharepoint.com URLs, so the cloud cannot be inferred from the URL.

    The script is idempotent: every object is checked first and skipped if it already exists. The SUP group
    grants and the -OwnerEmail site collection admin step are additive and re-applied on every run.
    It does NOT modify columns that already exist (re-run safe, but it will not "fix" a wrong column).
    Supports -WhatIf: read-only checks run, every create/modify step is only reported.

    Creates: the communication site; 7 lists; the Permit Records library (Open Projects, Closed Projects,
    _Templates); the owners-only SUP Admin library (solution backups); the 5 SUP groups and permissions;
    indexes; the 6 Permits views and the "Changed this year" view on ConditionLibrary; column formatting;
    Settings rows (including blank Approvers, DefaultCoordinator and DefaultSuperintendent rows);
    PermitTypes and ConditionLibrary seed data; optionally sample permits.

    Does NOT: add the flow service account to SUP Owners (do this by hand: see README), set the site
    time zone, add people to the groups, or empty the site's two default groups.

.PARAMETER TenantUrl
    Root SharePoint URL, e.g. https://contoso.sharepoint.com

.PARAMETER SiteAlias
    Site URL segment. Default SpecialUsePermits -> https://contoso.sharepoint.com/sites/SpecialUsePermits

.PARAMETER ClientId
    Application (client) ID of the customer's own Entra ID app (see above).

.PARAMETER OwnerEmail
    UPN of the program's site owner. Added as a site collection administrator and to "SUP Owners".
    Also used as Coordinator/Superintendent on sample permits. The account running the script is the
    site's primary owner, so it keeps access to finish provisioning.

.PARAMETER AzureEnvironment
    Production (commercial, default), USGovernment (GCC), USGovernmentHigh (GCC High) or USGovernmentDoD.

.PARAMETER ProgramMailbox
    Value for the Settings row ProgramMailbox (the shared mailbox). Default sup-permits@agency.example.

.PARAMETER Approvers
    Value for the Settings row Approvers: approving officials' emails separated by ";" with no spaces.
    Read by the app (formula 6-A). Default blank; a blank row means nobody is treated as an approver.
    Like every Settings value, it is written only when the row is first created; later runs skip the row.

.PARAMETER DefaultCoordinator
    Value for the Settings row DefaultCoordinator: one email address, used by F1b add-on A.
    Default blank; a blank row leaves Coordinator empty. A wrong address makes F1b fail.

.PARAMETER DefaultSuperintendent
    Value for the Settings row DefaultSuperintendent: one email address, used by F1b add-on A.
    Default blank; a blank row leaves Superintendent empty.

.PARAMETER ImportSamplePermits
    Also import Permits-sample.csv (12 fictitious permits) with folders. Test sites only.
    Sample dates are written relative to 2026-11-23 and shifted so they stay relative to today.

.EXAMPLE
    ./Provision-SUPSite.ps1 -TenantUrl https://contoso.sharepoint.com -ClientId 00000000-0000-0000-0000-000000000000 -OwnerEmail admin@contoso.com -SiteAlias SUP-Test -ImportSamplePermits -WhatIf
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory)] [ValidatePattern('^https://[a-zA-Z0-9-]+\.sharepoint\.(com|us)/?$')] [string] $TenantUrl,
    [string] $SiteAlias = 'SpecialUsePermits',
    [Parameter(Mandatory)] [guid] $ClientId,
    [Parameter(Mandatory)] [string] $OwnerEmail,
    [ValidateSet('Production', 'USGovernment', 'USGovernmentHigh', 'USGovernmentDoD')] [string] $AzureEnvironment = 'Production',
    [string] $SiteTitle = 'Special Use Permits',
    [string] $ProgramMailbox = 'sup-permits@agency.example',
    [string] $Approvers = '',
    [string] $DefaultCoordinator = '',
    [string] $DefaultSuperintendent = '',
    [string] $KitPath = $PSScriptRoot,
    [switch] $ImportSamplePermits
)

$ErrorActionPreference = 'Stop'
$script:Cmd = $PSCmdlet
$script:Failures = [System.Collections.Generic.List[string]]::new()

# ---------------------------------------------------------------------------------------------
# Constants (exactly as spec/data-model.md).
# ---------------------------------------------------------------------------------------------
$StatusActive = 'Active'
$StatusValues = @('Received', 'Under Review', 'Draft Permit', 'Out for Permittee Signature',
    'Out for Superintendent Signature', 'Executed', $StatusActive, 'Closed', 'Withdrawn', 'Denied')
$ClosedStatuses = @('Closed', 'Withdrawn', 'Denied')
$OpenStatuses = $StatusValues | Where-Object { $_ -notin $ClosedStatuses }
$UnexecutedStatuses = @('Received', 'Under Review', 'Draft Permit', 'Out for Permittee Signature', 'Out for Superintendent Signature')
$ImpactValues = @('Ground disturbance', 'Near stream, river or wetland', 'Tree clearing',
    'Structures or temporary facilities', 'Motorized equipment or vehicles off road',
    'Large group or public event', 'Night activity or lighting', 'Commercial filming or photography',
    'Utility or right-of-way work', 'Use of drones (UAS)')
$CategoryValues = @('General', 'Insurance & Liability', 'Cultural Resources', 'Soils & Erosion', 'Water Resources',
    'Wildlife', 'Vegetation', 'Public Safety', 'Operations')
$DocTypeValues = @('Application', 'Draft Permit', 'COI', 'Site Plan', 'Correspondence', 'Compliance Record', 'Executed Permit', 'Other')
$EventTypeValues = @('Created', 'Status Changed', 'Field Changed', 'Document Added', 'Signature Sent', 'Signed', 'Reminder Sent', 'Moved to Closed')

$TenantUrl = $TenantUrl.TrimEnd('/')
$SiteUrl = "$TenantUrl/sites/$SiteAlias"
$SiteRelUrl = "/sites/$SiteAlias"
$AdminUrl = $TenantUrl -replace '^https://([^.]+)\.', 'https://$1-admin.'

# ---------------------------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------------------------
function Write-Step([string]$Message) { Write-Host "==> $Message" -ForegroundColor Cyan }
function Write-Skip([string]$Message) { Write-Host "    skip: $Message" -ForegroundColor DarkGray }
function Write-Done([string]$Message) { Write-Host "    ok:   $Message" -ForegroundColor Green }

# Runs a create/modify action behind ShouldProcess (so -WhatIf works) with its own try/catch.
function Invoke-Step {
    param([string]$Target, [string]$Action, [scriptblock]$Script)
    if (-not $script:Cmd.ShouldProcess($Target, $Action)) { return }
    try {
        & $Script
        Write-Done "$Action $Target"
    }
    catch {
        $msg = "$Action $Target :: $($_.Exception.Message)"
        $script:Failures.Add($msg)
        Write-Host "    FAIL: $msg" -ForegroundColor Red
    }
}

# All existence checks swallow "not found" errors and return nothing (some PnP Get-* cmdlets throw instead of returning nothing).
# Nothing, not $null, so a pipeline after it runs zero times. Run with -Verbose to see the swallowed error
# (a 403 or throttling looks the same as "does not exist" otherwise).
function Get-OrNull([scriptblock]$Get) { try { & $Get } catch { Write-Verbose "lookup failed: $($_.Exception.Message)" } }
function Get-ListOrNull([string]$Title) { Get-OrNull { Get-PnPList -Identity $Title -ErrorAction Stop } }

function Get-FieldOrNull([string]$List, [string]$Name) {
    try { Get-PnPField -List $List -Identity $Name -ErrorAction Stop } catch { $null }
}

function ConvertTo-XmlText([string]$s) { [System.Security.SecurityElement]::Escape($s) }

# Builds CAML field XML. DisplayName = internal Name at creation (guarantees the internal name),
# the friendly display name is applied afterwards with Set-PnPField.
function New-FieldXml([hashtable]$f) {
    $n = $f.Name
    $common = "ID=`"{$([guid]::NewGuid())}`" Name=`"$n`" StaticName=`"$n`" DisplayName=`"$n`""
    if ($f.Indexed) { $common += ' Indexed="TRUE"' }
    if ($f.Unique) { $common += ' EnforceUniqueValues="TRUE"' }
    $choices = ''
    if ($f.Choices) { $choices = '<CHOICES>' + (($f.Choices | ForEach-Object { "<CHOICE>$(ConvertTo-XmlText $_)</CHOICE>" }) -join '') + '</CHOICES>' }
    switch ($f.Type) {
        'Text' { "<Field Type=`"Text`" $common MaxLength=`"255`" />" }
        'Note' { "<Field Type=`"Note`" $common NumLines=`"6`" RichText=`"FALSE`" AppendOnly=`"FALSE`" />" }
        'Number' { "<Field Type=`"Number`" $common Decimals=`"$($f.Decimals ?? 0)`" />" }
        'Boolean' { "<Field Type=`"Boolean`" $common><Default>0</Default></Field>" }
        'DateOnly' { "<Field Type=`"DateTime`" $common Format=`"DateOnly`" FriendlyDisplayFormat=`"Disabled`" />" }
        'DateTime' { "<Field Type=`"DateTime`" $common Format=`"DateTime`" FriendlyDisplayFormat=`"Disabled`" />" }
        'Choice' { "<Field Type=`"Choice`" $common Format=`"Dropdown`" FillInChoice=`"FALSE`">$choices</Field>" }
        'MultiChoice' { "<Field Type=`"MultiChoice`" $common FillInChoice=`"FALSE`">$choices</Field>" }
        'User' { "<Field Type=`"User`" $common UserSelectionMode=`"PeopleOnly`" UserSelectionScope=`"0`" Mult=`"FALSE`" />" }
        'URL' { "<Field Type=`"URL`" $common Format=`"Hyperlink`" />" }
        'Lookup' { "<Field Type=`"Lookup`" $common List=`"{$($f.LookupListId)}`" ShowField=`"Title`" />" }
        'LookupMulti' { "<Field Type=`"LookupMulti`" $common List=`"{$($f.LookupListId)}`" ShowField=`"Title`" Mult=`"TRUE`" />" }
        default { throw "Unknown field type $($f.Type)" }
    }
}

function Ensure-List([string]$Title, [string]$Url, [string]$Template = 'GenericList', [string]$DisplayTitle) {
    $existing = Get-ListOrNull $Title
    if (-not $existing -and $DisplayTitle) { $existing = Get-ListOrNull $DisplayTitle }
    if ($existing) { Write-Skip "list $Title exists"; return }
    Invoke-Step $Title 'Create list' {
        New-PnPList -Title $Title -Url $Url -Template $Template -OnQuickLaunch | Out-Null
        if ($DisplayTitle) { Set-PnPList -Identity $Title -Title $DisplayTitle | Out-Null }
    }
}

function Ensure-Fields([string]$List, [array]$Fields) {
    foreach ($f in $Fields) {
        if (Get-FieldOrNull $List $f.Name) { Write-Skip "$List.$($f.Name) exists"; continue }
        if ($f.Type -like 'Lookup*') {
            $target = Get-ListOrNull $f.LookupList
            if (-not $target) { $script:Failures.Add("$List.$($f.Name): lookup target $($f.LookupList) missing"); continue }
            $f.LookupListId = $target.Id
        }
        $xml = New-FieldXml $f
        Invoke-Step "$List.$($f.Name)" 'Add field' {
            Add-PnPFieldFromXml -List $List -FieldXml $xml | Out-Null
            if ($f.Display -and $f.Display -ne $f.Name) {
                Set-PnPField -List $List -Identity $f.Name -Values @{ Title = $f.Display } | Out-Null
            }
            # Add to the default view so the column is visible in "All Items".
            $v = Get-PnPView -List $List | Where-Object DefaultView
            if ($v -and ($v.ViewFields -notcontains $f.Name)) {
                Set-PnPView -List $List -Identity $v.Id -Fields (@($v.ViewFields) + $f.Name) | Out-Null
            }
        }
    }
}

function Find-Item([string]$List, [string]$Field, [string]$Value) {
    $caml = "<View><Query><Where><Eq><FieldRef Name='$Field'/><Value Type='Text'>$(ConvertTo-XmlText $Value)</Value></Eq></Where></Query><RowLimit>1</RowLimit></View>"
    Get-OrNull { Get-PnPListItem -List $List -Query $caml -ErrorAction Stop | Select-Object -First 1 }
}

# Same rule as F1b in flows.md: strip ~ " # % & * : < > ? / \ { | } and spaces, collapse repeated dots,
# max 30 chars, then drop a trailing dot (SharePoint rejects folder names that end in "." or contain "..").
function Get-ShortName([string]$s) {
    $clean = ($s -replace '[~"#%&*:<>?/\\{|} ]', '') -replace '\.{2,}', '.'
    if ($clean.Length -gt 30) { $clean = $clean.Substring(0, 30) }
    $clean.TrimEnd('.')
}

function Split-List([string]$s) { @(($s -split ';') | ForEach-Object { $_.Trim() } | Where-Object { $_ }) }

function New-InCaml([string]$Field, [string[]]$Values) {
    "<In><FieldRef Name='$Field'/><Values>" + (($Values | ForEach-Object { "<Value Type='Text'>$(ConvertTo-XmlText $_)</Value>" }) -join '') + '</Values></In>'
}

# =============================================================================================
# 1. Site
#    Communication site (New-PnPSite -Type CommunicationSite), not a group-connected team site:
#    - Permissions are managed purely with the SharePoint groups the spec defines; a team site would
#      add an M365 group whose members silently get Edit everywhere, fighting the AuditLog/Compliance
#      permission design.
#    - No unused group mailbox / Planner / Teams sprawl; the program uses its own shared mailbox.
#    - A Team can still be pointed at this site later via a Teams tab if staff want chat.
# =============================================================================================
Write-Step "Connecting to admin center $AdminUrl"
Connect-PnPOnline -Url $AdminUrl -ClientId $ClientId -Interactive -AzureEnvironment $AzureEnvironment

Write-Step "Site $SiteUrl"
$site = Get-OrNull { Get-PnPTenantSite -Identity $SiteUrl -ErrorAction Stop }
if ($site) {
    Write-Skip 'site exists'
}
else {
    # The running account becomes the owner, so it has rights on the new site; -OwnerEmail is added below.
    Invoke-Step $SiteUrl 'Create communication site' {
        New-PnPSite -Type CommunicationSite -Title $SiteTitle -Url $SiteUrl -Lcid 1033 -Wait | Out-Null
    }
    $site = Get-OrNull { Get-PnPTenantSite -Identity $SiteUrl -ErrorAction Stop }
}
if (-not $site) {
    if ($WhatIfPreference) { Write-Host 'WhatIf: site does not exist yet, so only the site creation line can be previewed. Stopping.' -ForegroundColor Yellow; return }
    throw "Site $SiteUrl not available; cannot continue."
}

Write-Step "Connecting to $SiteUrl"
Connect-PnPOnline -Url $SiteUrl -ClientId $ClientId -Interactive -AzureEnvironment $AzureEnvironment
Invoke-Step $OwnerEmail 'Add as site collection admin' { Add-PnPSiteCollectionAdmin -Owners $OwnerEmail | Out-Null }
Write-Host '    NOTE: set Site settings > Regional settings > Time zone to the office time zone (date-only columns and reminder dates depend on it).' -ForegroundColor Yellow

# =============================================================================================
# 2. Lists and columns (lookup targets first)
# =============================================================================================
$ListDefs = [ordered]@{
    PermitTypes      = @{ Url = 'Lists/PermitTypes'; Fields = @(
            @{ Name = 'TemplateFile'; Type = 'Text'; Display = 'Template File' }
            @{ Name = 'DefaultTermDays'; Type = 'Number'; Display = 'Default Term (days)' }
            @{ Name = 'Prefix'; Type = 'Text' }
        )
    }
    Settings         = @{ Url = 'Lists/Settings'; Fields = @(
            @{ Name = 'Value'; Type = 'Text' }
        )
    }
    ConditionLibrary = @{ Url = 'Lists/ConditionLibrary'; Fields = @(
            @{ Name = 'ConditionCode'; Type = 'Text'; Display = 'Condition Code'; Indexed = $true }
            @{ Name = 'Category'; Type = 'Choice'; Choices = $CategoryValues }
            @{ Name = 'ConditionText'; Type = 'Note'; Display = 'Condition Text' }
            @{ Name = 'AppliesToTypes'; Type = 'LookupMulti'; LookupList = 'PermitTypes'; Display = 'Applies To Types' }
            @{ Name = 'TriggerImpacts'; Type = 'MultiChoice'; Choices = $ImpactValues; Display = 'Trigger Impacts' }
            @{ Name = 'AlwaysInclude'; Type = 'Boolean'; Display = 'Always Include' }
            @{ Name = 'Active'; Type = 'Boolean' }
            @{ Name = 'SortOrder'; Type = 'Number'; Display = 'Sort Order' }
        )
    }
    Permits          = @{ Url = 'Lists/Permits'; Fields = @(
            # NOTE: EnforceUniqueValues on PermitNumber — see README "Doubts" (blank values on new items).
            @{ Name = 'PermitNumber'; Type = 'Text'; Display = 'Permit Number'; Indexed = $true; Unique = $true }
            @{ Name = 'PermitType'; Type = 'Lookup'; LookupList = 'PermitTypes'; Display = 'Permit Type' }
            @{ Name = 'Status'; Type = 'Choice'; Choices = $StatusValues; Indexed = $true }
            @{ Name = 'ApplicantName'; Type = 'Text'; Display = 'Applicant Name' }
            @{ Name = 'ApplicantOrg'; Type = 'Text'; Display = 'Applicant Organization' }
            @{ Name = 'ApplicantEmail'; Type = 'Text'; Display = 'Applicant Email' }
            @{ Name = 'ApplicantPhone'; Type = 'Text'; Display = 'Applicant Phone' }
            @{ Name = 'ProjectTitle'; Type = 'Text'; Display = 'Project Title' }
            @{ Name = 'ProjectDescription'; Type = 'Note'; Display = 'Project Description' }
            @{ Name = 'LocationName'; Type = 'Text'; Display = 'Location' }
            @{ Name = 'Latitude'; Type = 'Number'; Decimals = 6 }
            @{ Name = 'Longitude'; Type = 'Number'; Decimals = 6 }
            @{ Name = 'Impacts'; Type = 'MultiChoice'; Choices = $ImpactValues }
            # ProposedStart indexed too (not required by spec) because F6 and a view filter on it.
            @{ Name = 'ProposedStart'; Type = 'DateOnly'; Display = 'Proposed Start'; Indexed = $true }
            @{ Name = 'ProposedEnd'; Type = 'DateOnly'; Display = 'Proposed End' }
            @{ Name = 'PermitExpiration'; Type = 'DateOnly'; Display = 'Permit Expiration'; Indexed = $true }
            @{ Name = 'ReceivedDate'; Type = 'DateOnly'; Display = 'Received Date' }
            @{ Name = 'Coordinator'; Type = 'User' }
            @{ Name = 'Superintendent'; Type = 'User' }
            @{ Name = 'COIReceived'; Type = 'Boolean'; Display = 'COI Received' }
            @{ Name = 'COIExpiration'; Type = 'DateOnly'; Display = 'COI Expiration'; Indexed = $true }
            @{ Name = 'PermitteeSigned'; Type = 'DateOnly'; Display = 'Permittee Signed' }
            @{ Name = 'SuperintendentSigned'; Type = 'DateOnly'; Display = 'Superintendent Signed' }
            @{ Name = 'ComplianceComplete'; Type = 'Boolean'; Display = 'Compliance Complete' }
            @{ Name = 'ClosedDate'; Type = 'DateOnly'; Display = 'Closed Date' }
            @{ Name = 'FolderUrl'; Type = 'URL'; Display = 'Folder' }
            @{ Name = 'FolderPath'; Type = 'Text'; Display = 'Folder Path' }
            @{ Name = 'SignatureRequestId'; Type = 'Text'; Display = 'Signature Request Id' }
            @{ Name = 'LastReminderKey'; Type = 'Text'; Display = 'Last Reminder Key' }
            @{ Name = 'SourceSubmissionId'; Type = 'Text'; Display = 'Source Submission Id'; Indexed = $true }
        )
    }
    PermitConditions = @{ Url = 'Lists/PermitConditions'; Fields = @(
            @{ Name = 'Permit'; Type = 'Lookup'; LookupList = 'Permits'; Indexed = $true }
            @{ Name = 'Condition'; Type = 'Lookup'; LookupList = 'ConditionLibrary' }
            @{ Name = 'ConditionText'; Type = 'Note'; Display = 'Condition Text' }
            @{ Name = 'Source'; Type = 'Choice'; Choices = @('Suggested', 'Added by staff') }
            @{ Name = 'Included'; Type = 'Boolean' }
            @{ Name = 'SortOrder'; Type = 'Number'; Display = 'Sort Order' }
        )
    }
    ComplianceItems  = @{ Url = 'Lists/ComplianceItems'; Fields = @(
            @{ Name = 'Permit'; Type = 'Lookup'; LookupList = 'Permits'; Indexed = $true }
            @{ Name = 'DueDate'; Type = 'DateOnly'; Display = 'Due Date' }
            @{ Name = 'Completed'; Type = 'Boolean' }
            @{ Name = 'CompletedDate'; Type = 'DateOnly'; Display = 'Completed Date' }
            @{ Name = 'EvidenceUrl'; Type = 'URL'; Display = 'Evidence' }
            @{ Name = 'AssignedTo'; Type = 'User'; Display = 'Assigned To' }
        )
    }
    AuditLog         = @{ Url = 'Lists/AuditLog'; Fields = @(
            @{ Name = 'PermitId'; Type = 'Number'; Display = 'Permit Id'; Indexed = $true }
            @{ Name = 'EventType'; Type = 'Choice'; Choices = $EventTypeValues; Display = 'Event Type' }
            @{ Name = 'Detail'; Type = 'Note' }
            @{ Name = 'Actor'; Type = 'Text' }
            @{ Name = 'EventTime'; Type = 'DateTime'; Display = 'Event Time' }
        )
    }
}

foreach ($name in $ListDefs.Keys) {
    Write-Step "List $name"
    Ensure-List -Title $name -Url $ListDefs[$name].Url
    if (Get-ListOrNull $name) {
        Ensure-Fields -List $name -Fields $ListDefs[$name].Fields
    }
}

Write-Step 'List settings (Title optional where flows set it, versioning, indexes)'
foreach ($l in 'Permits', 'PermitConditions', 'AuditLog', 'ComplianceItems') {
    if (Get-ListOrNull $l) {
        Invoke-Step "$l.Title" 'Make optional' { Set-PnPField -List $l -Identity Title -Values @{ Required = $false } | Out-Null }
    }
}
if (Get-ListOrNull 'Permits') {
    # Versioning is required by F7b and F2a (Get changes; status before/after via item versions).
    Invoke-Step 'Permits' 'Enable versioning (100 major)' { Set-PnPList -Identity Permits -EnableVersioning $true -MajorVersions 100 | Out-Null }
}
if (Get-ListOrNull 'Settings') {
    Invoke-Step 'Settings.Title' 'Index' { Set-PnPField -List Settings -Identity Title -Values @{ Indexed = $true } | Out-Null }
}

# =============================================================================================
# 3. Document library PermitRecords ("Permit Records") + folders
# =============================================================================================
Write-Step 'Library PermitRecords'
Ensure-List -Title 'PermitRecords' -Url 'PermitRecords' -Template DocumentLibrary -DisplayTitle 'Permit Records'
# Identify the library by its URL, not its display name, so a failed rename does not leave it unconfigured.
$LibId = 'PermitRecords'
$lib = Get-ListOrNull $LibId
if ($lib) {
    if ($lib.Title -ne 'Permit Records') {
        Invoke-Step $LibId 'Set display name Permit Records' { Set-PnPList -Identity $LibId -Title 'Permit Records' | Out-Null }
    }
    Ensure-Fields -List $LibId -Fields @(
        @{ Name = 'PermitNumber'; Type = 'Text'; Display = 'Permit Number'; Indexed = $true }
        @{ Name = 'DocType'; Type = 'Choice'; Choices = $DocTypeValues; Display = 'Doc Type' }
    )
    # -EnableAutoExpirationVersionTrim $false: -MajorVersions throws on a library whose version trimming is Automatic.
    Invoke-Step $LibId 'Enable versioning (100 major, no auto-trim)' {
        Set-PnPList -Identity $LibId -EnableVersioning $true -EnableAutoExpirationVersionTrim $false -MajorVersions 100 -ExpireVersionsAfterDays 0 | Out-Null
    }
    foreach ($folder in 'Open Projects', 'Closed Projects', '_Templates') {
        if (Get-OrNull { Get-PnPFolder -Url "PermitRecords/$folder" -ErrorAction Stop }) { Write-Skip "folder $folder exists"; continue }
        Invoke-Step "PermitRecords/$folder" 'Create folder' { Add-PnPFolder -Name $folder -Folder 'PermitRecords' | Out-Null }
    }
}
elseif (-not $WhatIfPreference) { $script:Failures.Add('PermitRecords library not found: columns, versioning and folders not configured') }

# SUP Admin: owners-only library for solution exports (build guide Steps 1.3 item 7, 1.6 item 5 and 8.4).
# Permissions are set in section 4 (unique permissions, SUP Owners only).
Write-Step 'Library SUPAdmin'
Ensure-List -Title 'SUPAdmin' -Url 'SUPAdmin' -Template DocumentLibrary -DisplayTitle 'SUP Admin'
$adminLib = Get-ListOrNull 'SUPAdmin'
if ($adminLib -and $adminLib.Title -ne 'SUP Admin') {
    Invoke-Step 'SUPAdmin' 'Set display name SUP Admin' { Set-PnPList -Identity 'SUPAdmin' -Title 'SUP Admin' | Out-Null }
}

# =============================================================================================
# 4. Groups and permissions
#    Site level: SUP Owners = Full Control (associated owners group), SUP Coordinators = Contribute,
#                SUP Compliance / SUP Approving Officials / SUP Viewers = Read.
#    ComplianceItems + Permit Records: unique perms, SUP Compliance = Contribute.
#    AuditLog, Settings, ConditionLibrary: unique perms, only owners can edit; everyone else Read (flows' connection account must be in SUP Owners).
#    SUP Admin: unique perms, SUP Owners only (no other SUP group is granted).
#    NOTE: role names "Full Control/Contribute/Read" are the English role definition names.
# =============================================================================================
Write-Step 'SharePoint groups'
$Groups = [ordered]@{
    'SUP Owners'             = @{ Role = 'Full Control'; Desc = 'Site owners and flow service account' }
    'SUP Coordinators'       = @{ Role = 'Contribute'; Desc = 'Permit coordinators (Contribute, not Edit: Edit would let them delete lists and change columns)' }
    'SUP Compliance'         = @{ Role = 'Read'; Desc = 'Compliance staff (Contribute on ComplianceItems and Permit Records)' }
    'SUP Approving Officials' = @{ Role = 'Read'; Desc = 'Superintendents / approving officials (sign via e-signature or Approvals)' }
    'SUP Viewers'            = @{ Role = 'Read'; Desc = 'Read-only' }
}
foreach ($g in $Groups.Keys) {
    if (Get-OrNull { Get-PnPGroup -Identity $g -ErrorAction Stop }) { Write-Skip "group $g exists" }
    else {
        Invoke-Step $g 'Create group' { New-PnPGroup -Title $g -Description $Groups[$g].Desc | Out-Null }
    }
    Invoke-Step $g "Grant site role $($Groups[$g].Role)" { Set-PnPGroupPermissions -Identity $g -AddRole $Groups[$g].Role | Out-Null }
}
Invoke-Step 'SUP Owners' 'Set as associated owners group' { Set-PnPGroup -Identity 'SUP Owners' -SetAssociatedGroup Owners | Out-Null }
Invoke-Step 'SUP Coordinators' 'Set as associated members group' { Set-PnPGroup -Identity 'SUP Coordinators' -SetAssociatedGroup Members | Out-Null }
Invoke-Step 'SUP Viewers' 'Set as associated visitors group' { Set-PnPGroup -Identity 'SUP Viewers' -SetAssociatedGroup Visitors | Out-Null }
Invoke-Step $OwnerEmail 'Add to SUP Owners' { Add-PnPGroupMember -LoginName $OwnerEmail -Group 'SUP Owners' | Out-Null }

Write-Step 'Unique permissions'
# Inheritance is broken WITHOUT copying (first run only), then every SUP group is granted explicitly. This removes
# the comm site's default "<Title> Members/Visitors" groups from these lists, so AuditLog really is owners-only edit.
# Grants are additive and run on every run, so a half-finished first run is repaired. Side effect: a grant an
# owner removed by hand is re-added.
$UniquePerms = [ordered]@{
    'ComplianceItems' = [ordered]@{ 'SUP Owners' = 'Full Control'; 'SUP Coordinators' = 'Contribute'; 'SUP Compliance' = 'Contribute'; 'SUP Approving Officials' = 'Read'; 'SUP Viewers' = 'Read' }
    'PermitRecords'   = [ordered]@{ 'SUP Owners' = 'Full Control'; 'SUP Coordinators' = 'Contribute'; 'SUP Compliance' = 'Contribute'; 'SUP Approving Officials' = 'Read'; 'SUP Viewers' = 'Read' }
    'AuditLog'        = [ordered]@{ 'SUP Owners' = 'Full Control'; 'SUP Coordinators' = 'Read'; 'SUP Compliance' = 'Read'; 'SUP Approving Officials' = 'Read'; 'SUP Viewers' = 'Read' }
    'Settings'        = [ordered]@{ 'SUP Owners' = 'Full Control'; 'SUP Coordinators' = 'Read'; 'SUP Compliance' = 'Read'; 'SUP Approving Officials' = 'Read'; 'SUP Viewers' = 'Read' }
    'ConditionLibrary'= [ordered]@{ 'SUP Owners' = 'Full Control'; 'SUP Coordinators' = 'Read'; 'SUP Compliance' = 'Read'; 'SUP Approving Officials' = 'Read'; 'SUP Viewers' = 'Read' }
    'SUPAdmin'        = [ordered]@{ 'SUP Owners' = 'Full Control' }
}
foreach ($l in $UniquePerms.Keys) {
    $list = Get-OrNull { Get-PnPList -Identity $l -Includes HasUniqueRoleAssignments -ErrorAction Stop }
    if (-not $list) { continue }
    $grants = $UniquePerms[$l]
    if (-not $list.HasUniqueRoleAssignments) {
        Invoke-Step $l 'Break inheritance (no copy)' { Set-PnPList -Identity $l -BreakRoleInheritance | Out-Null }
    }
    # Grants are additive, so they run every time and repair a half-finished first run.
    foreach ($grp in $grants.Keys) {
        Invoke-Step "$l / $grp" "Grant $($grants[$grp])" { Set-PnPListPermission -Identity $l -Group $grp -AddRole $grants[$grp] | Out-Null }
    }
}
Write-Host '    NOTE: SharePoint may add the account running this script directly to these lists; remove it if unwanted.' -ForegroundColor Yellow

# =============================================================================================
# 5. Seed data
# =============================================================================================
Write-Step 'Seed Settings'
$year = (Get-Date).Year
$SettingsSeed = [ordered]@{
    ReminderDaysPermitExpiry    = '60,30,7'
    ReminderDaysCOI             = '30,7'
    ReminderDaysStartUnexecuted = '30,14,7'
    ProgramMailbox              = $ProgramMailbox
    "NextSeq_$year"             = '1'
    "NextSeq_$($year + 1)"      = '1'   # pre-seeded for year rollover; F1b also creates it if missing
    # Optional rows (build guide Step 1.2). Blank by default: a blank value is ignored by the app and by F1b add-on A.
    Approvers                   = $Approvers
    DefaultCoordinator          = $DefaultCoordinator
    DefaultSuperintendent       = $DefaultSuperintendent
}
foreach ($k in $SettingsSeed.Keys) {
    if (Find-Item 'Settings' 'Title' $k) { Write-Skip "setting $k exists"; continue }
    Invoke-Step "Settings/$k" 'Add' { Add-PnPListItem -List Settings -Values @{ Title = $k; Value = $SettingsSeed[$k] } | Out-Null }
}

Write-Step 'Seed PermitTypes'
foreach ($row in Import-Csv (Join-Path $KitPath 'PermitTypes-seed.csv') -Encoding utf8) {
    if (Find-Item 'PermitTypes' 'Title' $row.Title) { Write-Skip "type $($row.Title) exists"; continue }
    $tpl = $row.TemplateFile -replace '^/sites/SpecialUsePermits', $SiteRelUrl
    Invoke-Step "PermitTypes/$($row.Title)" 'Add' {
        Add-PnPListItem -List PermitTypes -Values @{
            Title = $row.Title; TemplateFile = $tpl; DefaultTermDays = [int]$row.DefaultTermDays; Prefix = $row.Prefix
        } | Out-Null
    }
}
$TypeIds = @{}
# Dry run: the types are not created yet, so use placeholders and avoid false "unknown permit type" failures.
if ($WhatIfPreference) { Import-Csv (Join-Path $KitPath 'PermitTypes-seed.csv') -Encoding utf8 | ForEach-Object { $TypeIds[$_.Title] = 0 } }
Get-OrNull { Get-PnPListItem -List PermitTypes -PageSize 500 -ErrorAction Stop } | ForEach-Object { $TypeIds[$_['Title']] = $_.Id }

Write-Step 'Import ConditionLibrary'
foreach ($row in Import-Csv (Join-Path $KitPath 'ConditionLibrary-seed.csv') -Encoding utf8) {
    if (Find-Item 'ConditionLibrary' 'ConditionCode' $row.ConditionCode) { Write-Skip "condition $($row.ConditionCode) exists"; continue }
    $impacts = Split-List $row.TriggerImpacts
    $bad = $impacts | Where-Object { $_ -notin $ImpactValues }
    if ($bad) { $script:Failures.Add("$($row.ConditionCode): unknown impact(s) $($bad -join ', ')"); continue }
    $typeNames = Split-List $row.AppliesToTypes
    $missing = $typeNames | Where-Object { -not $TypeIds.ContainsKey($_) }
    if ($missing) { $script:Failures.Add("$($row.ConditionCode): unknown permit type(s) $($missing -join ', ')"); continue }
    $values = @{
        Title         = $row.Title
        ConditionCode = $row.ConditionCode
        Category      = $row.Category
        ConditionText = $row.ConditionText
        AlwaysInclude = ($row.AlwaysInclude -eq 'TRUE')
        Active        = $true
        SortOrder     = [int]$row.SortOrder
    }
    if ($impacts) { $values.TriggerImpacts = [string[]]$impacts }
    if ($typeNames) { $values.AppliesToTypes = @($typeNames | ForEach-Object { $TypeIds[$_] }) }
    Invoke-Step "ConditionLibrary/$($row.ConditionCode)" 'Add' { Add-PnPListItem -List ConditionLibrary -Values $values | Out-Null }
}

# =============================================================================================
# 6. Views and column formatting on Permits (same definitions as list-views.md)
# =============================================================================================
Write-Step 'Permits views'
$cols = @('LinkTitle', 'ProjectTitle', 'ApplicantOrg', 'PermitType', 'Status', 'Coordinator')
$Views = [ordered]@{
    'My open permits'                  = @{
        Fields = $cols + @('ProposedStart', 'PermitExpiration')
        Query  = "<GroupBy Collapse='FALSE'><FieldRef Name='Status'/></GroupBy><OrderBy><FieldRef Name='ProposedStart' Ascending='TRUE'/></OrderBy><Where><And><Eq><FieldRef Name='Coordinator' LookupId='TRUE'/><Value Type='Integer'><UserID Type='Integer'/></Value></Eq>$(New-InCaml 'Status' $OpenStatuses)</And></Where>"
    }
    'Expiring in 60 days'              = @{
        Fields = $cols + @('PermitExpiration', 'COIExpiration')
        Query  = "<OrderBy><FieldRef Name='PermitExpiration' Ascending='TRUE'/></OrderBy><Where><And><And>$(New-InCaml 'Status' @('Executed', $StatusActive))<Geq><FieldRef Name='PermitExpiration'/><Value Type='DateTime'><Today/></Value></Geq></And><Leq><FieldRef Name='PermitExpiration'/><Value Type='DateTime'><Today OffsetDays='60'/></Value></Leq></And></Where>"
    }
    'COI expiring'                     = @{
        Fields = $cols + @('COIReceived', 'COIExpiration', 'PermitExpiration')
        Query  = "<OrderBy><FieldRef Name='COIExpiration' Ascending='TRUE'/></OrderBy><Where><And><And>$(New-InCaml 'Status' $OpenStatuses)<IsNotNull><FieldRef Name='COIExpiration'/></IsNotNull></And><Leq><FieldRef Name='COIExpiration'/><Value Type='DateTime'><Today OffsetDays='30'/></Value></Leq></And></Where>"
    }
    'Awaiting signature'               = @{
        Fields = $cols + @('Superintendent', 'PermitteeSigned', 'SuperintendentSigned', 'ProposedStart')
        Query  = "<GroupBy Collapse='FALSE'><FieldRef Name='Status'/></GroupBy><OrderBy><FieldRef Name='ProposedStart' Ascending='TRUE'/></OrderBy><Where>$(New-InCaml 'Status' @('Out for Permittee Signature', 'Out for Superintendent Signature'))</Where>"
    }
    'Unexecuted, start within 30 days' = @{
        Fields = $cols + @('ProposedStart', 'COIReceived')
        Query  = "<OrderBy><FieldRef Name='ProposedStart' Ascending='TRUE'/></OrderBy><Where><And>$(New-InCaml 'Status' $UnexecutedStatuses)<Leq><FieldRef Name='ProposedStart'/><Value Type='DateTime'><Today OffsetDays='30'/></Value></Leq></And></Where>"
    }
    'Closed in last 365 days'          = @{
        # Rolling window, no yearly maintenance. Calendar-year alternative: see list-views.md section 6.
        Fields = $cols + @('ClosedDate', 'FolderUrl')
        Query  = "<OrderBy><FieldRef Name='ClosedDate' Ascending='FALSE'/></OrderBy><Where><And>$(New-InCaml 'Status' $ClosedStatuses)<Geq><FieldRef Name='ClosedDate'/><Value Type='DateTime'><Today OffsetDays='-365'/></Value></Geq></And></Where>"
    }
}
if (Get-ListOrNull 'Permits') {
    foreach ($v in $Views.Keys) {
        if (Get-OrNull { Get-PnPView -List Permits -Identity $v -ErrorAction Stop }) { Write-Skip "view $v exists"; continue }
        Invoke-Step "Permits/$v" 'Add view' {
            Add-PnPView -List Permits -Title $v -Fields $Views[$v].Fields -Query $Views[$v].Query -RowLimit 100 -Paged | Out-Null
        }
    }

    Write-Step 'Column formatting'
    $pill = Get-Content (Join-Path $KitPath 'formatting/status-pill.json') -Raw -Encoding utf8
    $date = Get-Content (Join-Path $KitPath 'formatting/date-overdue.json') -Raw -Encoding utf8
    $start = Get-Content (Join-Path $KitPath 'formatting/date-start.json') -Raw -Encoding utf8
    Invoke-Step 'Permits.Status' 'Apply status pill formatting' { Set-PnPField -List Permits -Identity Status -Values @{ CustomFormatter = $pill } | Out-Null }
    foreach ($d in 'PermitExpiration', 'COIExpiration') {
        Invoke-Step "Permits.$d" 'Apply overdue date formatting' { Set-PnPField -List Permits -Identity $d -Values @{ CustomFormatter = $date } | Out-Null }
    }
    Invoke-Step 'Permits.ProposedStart' 'Apply start-date formatting' { Set-PnPField -List Permits -Identity ProposedStart -Values @{ CustomFormatter = $start } | Out-Null }
}

# "Changed this year" on ConditionLibrary (build guide Step 2.4; list-views.md section 7): rolling 365 days on Modified.
Write-Step 'ConditionLibrary view'
$ChangedView = 'Changed this year'
if (Get-ListOrNull 'ConditionLibrary') {
    if (Get-OrNull { Get-PnPView -List ConditionLibrary -Identity $ChangedView -ErrorAction Stop }) { Write-Skip "view $ChangedView exists" }
    else {
        Invoke-Step "ConditionLibrary/$ChangedView" 'Add view' {
            Add-PnPView -List ConditionLibrary -Title $ChangedView -Fields @('LinkTitle', 'ConditionCode', 'Category', 'Active', 'Modified', 'Editor') -Query "<OrderBy><FieldRef Name='Modified' Ascending='FALSE'/></OrderBy><Where><Geq><FieldRef Name='Modified'/><Value Type='DateTime'><Today OffsetDays='-365'/></Value></Geq></Where>" -RowLimit 100 -Paged | Out-Null
        }
    }
}

# =============================================================================================
# 7. Optional: sample permits (TEST SITES ONLY)
# =============================================================================================
if ($ImportSamplePermits) {
    Write-Step 'Import sample permits'
    $anchor = [datetime]'2026-11-23'
    $shift = ((Get-Date).Date - $anchor).Days
    $dateCols = 'ReceivedDate', 'ProposedStart', 'ProposedEnd', 'PermitExpiration', 'COIExpiration', 'PermitteeSigned', 'SuperintendentSigned', 'ClosedDate'
    $maxSeq = @{}
    foreach ($row in Import-Csv (Join-Path $KitPath 'Permits-sample.csv') -Encoding utf8) {
        if (Find-Item 'Permits' 'PermitNumber' $row.PermitNumber) { Write-Skip "permit $($row.PermitNumber) exists"; continue }
        $isClosed = $row.Status -in $ClosedStatuses
        $top = if ($isClosed) { 'Closed Projects' } else { 'Open Projects' }
        $short = if ($row.ApplicantOrg) { $row.ApplicantOrg } else { $row.ApplicantName }
        $folderName = "$($row.PermitNumber)_$(Get-ShortName $short)_$(Get-ShortName $row.LocationName)"
        $folderPath = "$SiteRelUrl/PermitRecords/$top/$folderName"
        $values = @{
            Title = $row.PermitNumber; PermitNumber = $row.PermitNumber; Status = $row.Status
            PermitType = $TypeIds[$row.PermitType]
            ApplicantName = $row.ApplicantName; ApplicantOrg = $row.ApplicantOrg; ApplicantEmail = $row.ApplicantEmail
            ApplicantPhone = $row.ApplicantPhone; ProjectTitle = $row.ProjectTitle; ProjectDescription = $row.ProjectDescription
            LocationName = $row.LocationName
            Impacts = [string[]](Split-List $row.Impacts)
            COIReceived = ($row.COIReceived -eq 'TRUE'); ComplianceComplete = ($row.ComplianceComplete -eq 'TRUE')
            Coordinator = $OwnerEmail; Superintendent = $OwnerEmail
            FolderPath = $folderPath
            FolderUrl = "$TenantUrl$($folderPath -replace ' ', '%20'), $folderName"
        }
        if ($row.Latitude) { $values.Latitude = [double]$row.Latitude; $values.Longitude = [double]$row.Longitude }
        foreach ($c in $dateCols) {
            if ($row.$c) { $values[$c] = ([datetime]$row.$c).AddDays($shift).ToString('yyyy-MM-dd') }
        }
        Invoke-Step "Permits/$($row.PermitNumber)" 'Add sample permit + folder' {
            if (-not (Get-OrNull { Get-PnPFolder -Url "PermitRecords/$top/$folderName" -ErrorAction Stop })) {
                Add-PnPFolder -Name $folderName -Folder "PermitRecords/$top" | Out-Null
            }
            Add-PnPListItem -List Permits -Values $values | Out-Null
        }
        $parts = $row.PermitNumber -split '-'
        $maxSeq[$parts[1]] = [Math]::Max([int]($maxSeq[$parts[1]] ?? 0), [int]$parts[2])
    }
    # Keep F1b numbering ahead of the sample numbers.
    foreach ($y in $maxSeq.Keys) {
        $item = Find-Item 'Settings' 'Title' "NextSeq_$y"
        $next = $maxSeq[$y] + 1
        Invoke-Step "Settings/NextSeq_$y" "Set to at least $next" {
            if ($item) { if ([int]$item['Value'] -lt $next) { Set-PnPListItem -List Settings -Identity $item.Id -Values @{ Value = "$next" } | Out-Null } }
            else { Add-PnPListItem -List Settings -Values @{ Title = "NextSeq_$y"; Value = "$next" } | Out-Null }
        }
    }
    Write-Host "    Sample dates shifted by $shift day(s) from the 2026-11-23 anchor." -ForegroundColor Yellow
}

# =============================================================================================
# Summary
# =============================================================================================
Write-Host ''
if ($script:Failures.Count) {
    Write-Host "Completed with $($script:Failures.Count) failure(s):" -ForegroundColor Red
    $script:Failures | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red }
    exit 1
}
Write-Host "Provisioning complete: $SiteUrl" -ForegroundColor Green
Write-Host 'Next (by hand): add the flow service account to SUP Owners, set the site time zone, add people to the groups,' -ForegroundColor Yellow
Write-Host '      upload Word templates to Permit Records/_Templates, then build the flows in flows.md (README run order).' -ForegroundColor Yellow
