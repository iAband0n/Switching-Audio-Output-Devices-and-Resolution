param([Parameter(Mandatory = $true)][string]$DeviceId)

$ErrorActionPreference = 'Stop'

Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;

public enum ERole { eConsole = 0, eMultimedia = 1, eCommunications = 2 }

[ComImport, Guid("870af99c-171d-4f9e-af0d-e63df40c2bc9")]
public class PolicyConfigClient {}

[ComImport, InterfaceType(ComInterfaceType.InterfaceIsIUnknown), Guid("f8679f50-850a-41cf-9c72-430f290290c8")]
public interface IPolicyConfig {
    int GetMixFormat();
    int GetDeviceFormat();
    int ResetDeviceFormat();
    int SetDeviceFormat();
    int GetProcessingPeriod();
    int SetProcessingPeriod();
    int GetShareMode();
    int SetShareMode();
    int GetPropertyValue();
    int SetPropertyValue();
    int SetDefaultEndpoint([MarshalAs(UnmanagedType.LPWStr)] string wszDeviceId, ERole role);
    int SetEndpointVisibility();
}

public static class AudioSwitcher {
    public static void SetDefault(string deviceId) {
        var policy = (IPolicyConfig)(new PolicyConfigClient());
        Marshal.ThrowExceptionForHR(policy.SetDefaultEndpoint(deviceId, ERole.eConsole));
        Marshal.ThrowExceptionForHR(policy.SetDefaultEndpoint(deviceId, ERole.eMultimedia));
    }
}
"@

[AudioSwitcher]::SetDefault($DeviceId)
