function Enter-CandidateValidationLock([string]$Directory) {
    $lockPath=Join-Path $Directory '.validation.lock'
    try {
        # The OS releases this exclusive handle after termination or power loss.
        # A leftover filename is harmless; an active owner's handle blocks Open.
        return [IO.File]::Open($lockPath,[IO.FileMode]::OpenOrCreate,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None)
    } catch [IO.IOException] {
        throw "Candidate validation is active or its directory is inaccessible: $lockPath. $($_.Exception.Message)"
    }
}
