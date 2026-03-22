import { useTranslation } from "react-i18next";
import { useQuery } from "@tanstack/react-query";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { invoke } from "@tauri-apps/api/core";
import { Loader2 } from "lucide-react";

interface InstalledTerminal {
  id: string;
  name: string;
  path: string | null;
}

async function scanTerminals(): Promise<InstalledTerminal[]> {
  return await invoke("scan_installed_terminals");
}

// Default terminal if none selected
function getDefaultTerminal(terminals: InstalledTerminal[]): string {
  // Prefer Terminal.app on macOS, wt on Windows, gnome-terminal on Linux
  const preferredOrder = ["terminal", "wt", "gnome-terminal", "iterm2", "powershell", "cmd"];
  for (const id of preferredOrder) {
    if (terminals.some(t => t.id === id)) {
      return id;
    }
  }
  // Fall back to first available
  return terminals[0]?.id || "terminal";
}

export interface TerminalSettingsProps {
  value?: string;
  onChange: (value: string) => void;
}

export function TerminalSettings({ value, onChange }: TerminalSettingsProps) {
  const { t } = useTranslation();

  const { data: terminals, isLoading, error } = useQuery({
    queryKey: ["installed-terminals"],
    queryFn: scanTerminals,
  });

  // Use value or default
  const currentValue = value || (terminals ? getDefaultTerminal(terminals) : "terminal");

  if (isLoading) {
    return (
      <section className="space-y-2">
        <header className="space-y-1">
          <h3 className="text-sm font-medium">{t("settings.terminal.title")}</h3>
          <p className="text-xs text-muted-foreground">
            {t("settings.terminal.description")}
          </p>
        </header>
        <div className="flex items-center gap-2 text-muted-foreground">
          <Loader2 className="h-4 w-4 animate-spin" />
          <span className="text-sm">{t("common.loading")}</span>
        </div>
      </section>
    );
  }

  if (error || !terminals || terminals.length === 0) {
    // Fallback to static options if scan fails
    return (
      <section className="space-y-2">
        <header className="space-y-1">
          <h3 className="text-sm font-medium">{t("settings.terminal.title")}</h3>
          <p className="text-xs text-muted-foreground">
            {t("settings.terminal.description")}
          </p>
        </header>
        <Select value={currentValue} onValueChange={onChange}>
          <SelectTrigger className="w-[200px]">
            <SelectValue placeholder="Terminal" />
          </SelectTrigger>
          <SelectContent>
            <SelectItem value="terminal">Terminal</SelectItem>
          </SelectContent>
        </Select>
        <p className="text-xs text-muted-foreground">
          {t("settings.terminal.scanFailed", { defaultValue: "无法检测已安装的终端" })}
        </p>
      </section>
    );
  }

  return (
    <section className="space-y-2">
      <header className="space-y-1">
        <h3 className="text-sm font-medium">{t("settings.terminal.title")}</h3>
        <p className="text-xs text-muted-foreground">
          {t("settings.terminal.description")}
        </p>
      </header>
      <Select value={currentValue} onValueChange={onChange}>
        <SelectTrigger className="w-[200px]">
          <SelectValue placeholder={t("settings.terminal.selectPlaceholder", { defaultValue: "选择终端" })} />
        </SelectTrigger>
        <SelectContent>
          {terminals.map((terminal) => (
            <SelectItem key={terminal.id} value={terminal.id}>
              {terminal.name}
            </SelectItem>
          ))}
        </SelectContent>
      </Select>
      <p className="text-xs text-muted-foreground">
        {t("settings.terminal.fallbackHint")}
      </p>
    </section>
  );
}