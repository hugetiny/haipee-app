import { useState } from "react";
import { useTranslation } from "react-i18next";
import {
  ExternalLink,
  Loader2,
  CheckCircle2,
  XCircle,
  MonitorSmartphone,
  Wifi,
} from "lucide-react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { toast } from "sonner";
import { settingsApi } from "@/lib/api";
import {
  useOpenClawJsonSection,
  useSaveOpenClawJsonSection,
} from "@/hooks/useOpenClaw";

type VerifyState = "idle" | "verifying" | "success" | "error";

interface GatewaySettings {
  port?: number;
  bindMode?: "local" | "remote";
  enableHttpChat?: boolean;
  authMode?: "none" | "token";
  token?: string;
  tailscale?: {
    mode?: "disabled" | "ephemeral" | "stateful";
    resetOnExit?: boolean;
    authKey?: string;
  };
}

/** Validate that an IP looks like a Tailscale IP: must start with 100. */
function isTailscaleIp(ip: string): boolean {
  return /^100\.\d{1,3}\.\d{1,3}\.\d{1,3}$/.test(ip.trim());
}

export function RemoteConnectPanel() {
  const { t } = useTranslation();

  const [tailscaleIp, setTailscaleIp] = useState("");
  const [verifyState, setVerifyState] = useState<VerifyState>("idle");
  const [errorMsg, setErrorMsg] = useState("");

  // Existing gateway settings – needed when we write back
  const { data: gatewayData } = useOpenClawJsonSection<GatewaySettings>(
    "gateway",
    {},
  );
  const saveGateway = useSaveOpenClawJsonSection("gateway");

  const handleOpenTailscale = async () => {
    try {
      await settingsApi.openExternal("https://tailscale.com/download");
    } catch {
      toast.error(t("notifications.openLinkFailed"));
    }
  };

  const handleVerify = async () => {
    const ip = tailscaleIp.trim();

    if (!ip) {
      setErrorMsg(t("remoteConnect.errorEmptyIp"));
      setVerifyState("error");
      return;
    }

    if (!isTailscaleIp(ip)) {
      setErrorMsg(t("remoteConnect.errorInvalidIp"));
      setVerifyState("error");
      return;
    }

    setVerifyState("verifying");
    setErrorMsg("");

    try {
      // Attempt a simple fetch to the OpenClaw health endpoint on the remote machine.
      // OpenClaw default port is 8000.
      const port = gatewayData?.port ?? 8000;
      const response = await fetch(`http://${ip}:${port}/health`, {
        signal: AbortSignal.timeout(5000),
      });

      if (response.ok) {
        setVerifyState("success");

        // Auto-configure: enable Tailscale ephemeral mode in openclaw.json
        try {
          await saveGateway.mutateAsync({
            ...gatewayData,
            tailscale: {
              ...(gatewayData?.tailscale ?? {}),
              mode: "ephemeral",
            },
          });
          toast.success(t("remoteConnect.configApplied"));
        } catch {
          // Gateway config failure is non-fatal – the connection still works.
          toast.error(t("remoteConnect.configFailed"));
        }
      } else {
        throw new Error(`HTTP ${response.status}`);
      }
    } catch {
      setVerifyState("error");
      setErrorMsg(t("remoteConnect.errorUnreachable"));
    }
  };

  const handleRetry = () => {
    setVerifyState("idle");
    setErrorMsg("");
  };

  return (
    <div className="space-y-6" data-testid="remote-connect-config">
      {/* Remote Connect Toggle */}
      <div className="flex items-center justify-between">
        <div className="space-y-0.5">
          <Label>{t("remoteConnect.toggleLabel", { defaultValue: "Enable Remote Connect" })}</Label>
          <p className="text-xs text-muted-foreground">
            {t("remoteConnect.toggleDescription", { defaultValue: "Allow remote connections to this device" })}
          </p>
        </div>
        <input
          type="checkbox"
          data-testid="remote-connect-toggle"
          className="h-4 w-4"
          defaultChecked
        />
      </div>

      {/* Port Input */}
      <div className="flex items-center gap-2 max-w-xs">
        <Label htmlFor="remote-port" className="text-sm font-medium">
          {t("remoteConnect.portLabel", { defaultValue: "Port" })}
        </Label>
        <input
          id="remote-port"
          type="number"
          data-testid="remote-connect-port"
          placeholder="8000"
          defaultValue="8000"
          className="flex-1 h-9 rounded-md border border-input bg-background px-3 text-sm"
        />
      </div>

      {/* Status */}
      <div data-testid="remote-connect-status" className="text-xs text-muted-foreground">
        {t("remoteConnect.statusReady", { defaultValue: "Ready to connect" })}
      </div>

      {/* Notice banner */}
      <div className="rounded-lg border border-violet-500/30 bg-violet-500/10 px-4 py-3 text-sm">
        <p className="font-medium text-violet-700 dark:text-violet-300 mb-1">
          {t("remoteConnect.noticeTitle")}
        </p>
        <p className="text-muted-foreground leading-relaxed">
          {t("remoteConnect.noticeBody")}
        </p>
      </div>

      {/* Step 1: Install Tailscale */}
      <div className="space-y-2">
        <div className="flex items-center gap-2">
          <span className="flex h-6 w-6 shrink-0 items-center justify-center rounded-full bg-violet-500 text-xs font-bold text-white">
            1
          </span>
          <Label className="text-sm font-medium">
            {t("remoteConnect.step1Title")}
          </Label>
        </div>
        <p className="pl-8 text-xs text-muted-foreground">
          {t("remoteConnect.step1Desc")}
        </p>
        <div className="pl-8">
          <Button
            variant="outline"
            size="sm"
            className="gap-1.5 h-8 text-xs"
            onClick={handleOpenTailscale}
          >
            <ExternalLink className="h-3.5 w-3.5" />
            {t("remoteConnect.step1Btn")}
          </Button>
        </div>
      </div>

      {/* Step 2: Enter remote Tailscale IP */}
      <div className="space-y-2">
        <div className="flex items-center gap-2">
          <span className="flex h-6 w-6 shrink-0 items-center justify-center rounded-full bg-violet-500 text-xs font-bold text-white">
            2
          </span>
          <Label htmlFor="tailscale-ip" className="text-sm font-medium">
            {t("remoteConnect.step2Title")}
          </Label>
        </div>
        <p className="pl-8 text-xs text-muted-foreground">
          {t("remoteConnect.step2Desc")}
        </p>
        <div className="pl-8 flex items-center gap-2 max-w-xs">
          <Wifi className="h-4 w-4 shrink-0 text-muted-foreground" />
          <Input
            id="tailscale-ip"
            placeholder="100.x.x.x"
            value={tailscaleIp}
            onChange={(e) => {
              setTailscaleIp(e.target.value);
              if (verifyState !== "idle") handleRetry();
            }}
            className="font-mono text-sm"
            disabled={verifyState === "verifying"}
          />
        </div>
      </div>

      {/* Step 3: Verify */}
      <div className="space-y-2">
        <div className="flex items-center gap-2">
          <span className="flex h-6 w-6 shrink-0 items-center justify-center rounded-full bg-violet-500 text-xs font-bold text-white">
            3
          </span>
          <Label className="text-sm font-medium">
            {t("remoteConnect.step3Title")}
          </Label>
        </div>
        <p className="pl-8 text-xs text-muted-foreground">
          {t("remoteConnect.step3Desc")}
        </p>
        <div className="pl-8 flex items-center gap-3">
          <Button
            size="sm"
            className="h-8 gap-1.5 text-xs bg-violet-600 hover:bg-violet-700"
            onClick={handleVerify}
            disabled={verifyState === "verifying" || verifyState === "success"}
          >
            {verifyState === "verifying" ? (
              <>
                <Loader2 className="h-3.5 w-3.5 animate-spin" />
                {t("remoteConnect.verifying")}
              </>
            ) : (
              <>
                <MonitorSmartphone className="h-3.5 w-3.5" />
                {t("remoteConnect.verifyBtn")}
              </>
            )}
          </Button>

          {verifyState === "success" && (
            <span className="flex items-center gap-1.5 text-xs text-green-600 dark:text-green-400 font-medium">
              <CheckCircle2 className="h-4 w-4" />
              {t("remoteConnect.successMsg")}
            </span>
          )}

          {verifyState === "error" && (
            <span className="flex items-center gap-1.5 text-xs text-red-600 dark:text-red-400">
              <XCircle className="h-4 w-4 shrink-0" />
              {errorMsg}
            </span>
          )}
        </div>

        {verifyState === "error" && (
          <p className="pl-8 text-xs text-muted-foreground">
            {t("remoteConnect.errorHint")}
          </p>
        )}
      </div>
    </div>
  );
}
