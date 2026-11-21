function Enter-WorkspaceLock([string]$Root, [string]$Operation) {
    $resolved = (Resolve-Path -LiteralPath $Root -ErrorAction Stop).ProviderPath
    $canonical = [IO.Path]::GetFullPath($resolved).TrimEnd('\','/').ToUpperInvariant()
    $sha = [Security.Cryptography.SHA256]::Create()
    try { $key = [BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($canonical))).Replace('-','') }
    finally { $sha.Dispose() }
    # A synchronous nested step can acquire the same mutex on its owning thread.
    # Terminating a holder abandons the mutex, so no stale PID file needs removal.
    $mutex = [Threading.Mutex]::new($false, ('ChibiRTS-Workspace-'+$key))
    try {
        try { $acquired = $mutex.WaitOne(0) }
        catch [Threading.AbandonedMutexException] { $acquired = $true }
        if (!$acquired) { throw "Workspace is busy. Cannot start $Operation in $resolved while another build, CI, verification, publication or cleanup is active." }
        return $mutex
    } catch { $mutex.Dispose(); throw }
}

function Exit-WorkspaceLock([Threading.Mutex]$Mutex) {
    $Mutex.ReleaseMutex()
    $Mutex.Dispose()
}
