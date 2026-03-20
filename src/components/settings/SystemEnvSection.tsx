import { useState, useCallback, useEffect } from "react";
import { useTranslation } from "react-i18next";
import { toast } from "sonner";
import {
  ChevronDown,
  ChevronRight,
  Plus,
  Pencil,
  Trash2,
  Variable,
  Loader2,
} from "lucide-react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import {
  Collapsible,
  CollapsibleContent,
  CollapsibleTrigger,
} from "@/components/ui/collapsible";
import {
  Dialog,
  DialogContent,
  DialogFooter,
  DialogHeader,
  DialogTitle,
  DialogDescription,
} from "@/components/ui/dialog";
import type { EnvConflict } from "@/types/env";
import {
  checkEnvConflicts,
  deleteEnvVars,
  setEnvVar,
} from "@/lib/api/env";

interface SystemEnvSectionProps {
  appType: string;
  appLabel: string;
  keywords: string[];
  defaultShellConfig: string;
  onEnvChange?: () => void;
}

export function SystemEnvSection({
  appType,
  appLabel,
  keywords,
  defaultShellConfig,
  onEnvChange,
}: SystemEnvSectionProps) {
  const { t } = useTranslation();
  const [isOpen, setIsOpen] = useState(false);
  const [envVars, setEnvVars] = useState<EnvConflict[]>([]);
  const [isLoading, setIsLoading] = useState(false);
  const [editingVar, setEditingVar] = useState<EnvConflict | null>(null);
  const [isAddDialogOpen, setIsAddDialogOpen] = useState(false);
  const [deleteConfirm, setDeleteConfirm] = useState<EnvConflict | null>(null);
  const [newVarName, setNewVarName] = useState("");
  const [newVarValue, setNewVarValue] = useState("");
  const [editVarValue, setEditVarValue] = useState("");
  const [isSaving, setIsSaving] = useState(false);

  const loadEnvVars = useCallback(async () => {
    setIsLoading(true);
    try {
      const conflicts = await checkEnvConflicts(appType);
      setEnvVars(conflicts);
    } catch (error) {
      console.error(`Failed to load env vars for ${appType}:`, error);
      toast.error(
        t("settings.envVar.loadFailed", { defaultValue: "加载环境变量失败" }),
      );
    } finally {
      setIsLoading(false);
    }
  }, [appType, t]);

  useEffect(() => {
    if (isOpen) {
      loadEnvVars();
    }
  }, [isOpen, loadEnvVars]);

  const handleAdd = async () => {
    if (!newVarName.trim()) {
      toast.error(
        t("settings.envVar.nameRequired", { defaultValue: "请输入变量名" }),
      );
      return;
    }

    setIsSaving(true);
    try {
      await setEnvVar(newVarName.trim(), newVarValue, defaultShellConfig);
      toast.success(
        t("settings.envVar.addSuccess", { defaultValue: "环境变量已添加" }),
      );
      setIsAddDialogOpen(false);
      setNewVarName("");
      setNewVarValue("");
      loadEnvVars();
      onEnvChange?.();
    } catch (error) {
      console.error("Failed to add env var:", error);
      toast.error(
        t("settings.envVar.addFailed", { defaultValue: "添加环境变量失败" }),
      );
    } finally {
      setIsSaving(false);
    }
  };

  const handleEdit = async () => {
    if (!editingVar) return;

    setIsSaving(true);
    try {
      await setEnvVar(editingVar.varName, editVarValue, defaultShellConfig);
      toast.success(
        t("settings.envVar.editSuccess", { defaultValue: "环境变量已更新" }),
      );
      setEditingVar(null);
      setEditVarValue("");
      loadEnvVars();
      onEnvChange?.();
    } catch (error) {
      console.error("Failed to edit env var:", error);
      toast.error(
        t("settings.envVar.editFailed", { defaultValue: "更新环境变量失败" }),
      );
    } finally {
      setIsSaving(false);
    }
  };

  const handleDelete = async () => {
    if (!deleteConfirm) return;

    setIsSaving(true);
    try {
      await deleteEnvVars([deleteConfirm]);
      toast.success(
        t("settings.envVar.deleteSuccess", { defaultValue: "环境变量已删除" }),
      );
      setDeleteConfirm(null);
      loadEnvVars();
      onEnvChange?.();
    } catch (error) {
      console.error("Failed to delete env var:", error);
      toast.error(
        t("settings.envVar.deleteFailed", { defaultValue: "删除环境变量失败" }),
      );
    } finally {
      setIsSaving(false);
    }
  };

  return (
    <>
      <Collapsible open={isOpen} onOpenChange={setIsOpen}>
        <CollapsibleTrigger className="flex items-center justify-between w-full p-4 rounded-lg glass-card hover:bg-muted/50 transition-colors">
          <div className="flex items-center gap-3">
            <Variable className="h-5 w-5 text-primary" />
            <div className="text-left">
              <h3 className="font-medium">
                {appLabel}{" "}
                <span className="text-muted-foreground font-normal">
                  ({keywords.join(", ")})
                </span>
              </h3>
              <p className="text-sm text-muted-foreground">
                {envVars.length > 0
                  ? t("settings.envVar.varCount", {
                      count: envVars.length,
                      defaultValue: `${envVars.length} 个环境变量`,
                    })
                  : t("settings.envVar.noVars", { defaultValue: "无环境变量" })}
              </p>
            </div>
          </div>
          {isOpen ? (
            <ChevronDown className="h-5 w-5 text-muted-foreground" />
          ) : (
            <ChevronRight className="h-5 w-5 text-muted-foreground" />
          )}
        </CollapsibleTrigger>
        <CollapsibleContent className="mt-2 space-y-2">
          <div className="pl-4 pr-4 pb-4">
            {isLoading ? (
              <div className="flex items-center justify-center py-4">
                <Loader2 className="h-5 w-5 animate-spin text-muted-foreground" />
              </div>
            ) : (
              <>
                {envVars.length > 0 ? (
                  <div className="space-y-2">
                    {envVars.map((envVar, index) => (
                      <div
                        key={`${envVar.varName}-${index}`}
                        className="flex items-center justify-between p-3 rounded-lg bg-muted/30 border border-border/50"
                      >
                        <div className="flex-1 min-w-0">
                          <div className="font-mono text-sm font-medium truncate">
                            {envVar.varName}
                          </div>
                          <div className="text-xs text-muted-foreground truncate">
                            {envVar.varValue
                              ? "••••••••"
                              : t("settings.envVar.emptyValue", {
                                  defaultValue: "(空)",
                                })}
                          </div>
                          <div className="text-xs text-muted-foreground mt-1">
                            {envVar.sourceType === "file"
                              ? envVar.sourcePath.split(":")[0]
                              : t("settings.envVar.systemEnv", {
                                  defaultValue: "系统环境变量",
                                })}
                          </div>
                        </div>
                        <div className="flex items-center gap-1 ml-2">
                          <Button
                            variant="ghost"
                            size="icon"
                            onClick={() => {
                              setEditingVar(envVar);
                              setEditVarValue(envVar.varValue);
                            }}
                            title={t("common.edit")}
                          >
                            <Pencil className="h-4 w-4" />
                          </Button>
                          <Button
                            variant="ghost"
                            size="icon"
                            onClick={() => setDeleteConfirm(envVar)}
                            title={t("common.delete")}
                          >
                            <Trash2 className="h-4 w-4 text-destructive" />
                          </Button>
                        </div>
                      </div>
                    ))}
                  </div>
                ) : (
                  <p className="text-sm text-muted-foreground py-2">
                    {t("settings.envVar.noVarsHint", {
                      defaultValue: "未检测到相关环境变量",
                    })}
                  </p>
                )}
                <Button
                  variant="outline"
                  size="sm"
                  className="mt-3"
                  onClick={() => setIsAddDialogOpen(true)}
                >
                  <Plus className="h-4 w-4 mr-2" />
                  {t("settings.envVar.addVar", { defaultValue: "添加环境变量" })}
                </Button>
              </>
            )}
          </div>
        </CollapsibleContent>
      </Collapsible>

      {/* Add Dialog */}
      <Dialog open={isAddDialogOpen} onOpenChange={setIsAddDialogOpen}>
        <DialogContent className="glass">
          <DialogHeader>
            <DialogTitle>
              {t("settings.envVar.addVar", { defaultValue: "添加环境变量" })}
            </DialogTitle>
          </DialogHeader>
          <div className="space-y-4 py-4">
            <div className="space-y-2">
              <Label>
                {t("settings.envVar.varName", { defaultValue: "变量名" })}
              </Label>
              <Input
                value={newVarName}
                onChange={(e) => setNewVarName(e.target.value)}
                placeholder={keywords[0] + "_API_KEY"}
              />
            </div>
            <div className="space-y-2">
              <Label>
                {t("settings.envVar.varValue", { defaultValue: "变量值" })}
              </Label>
              <Input
                value={newVarValue}
                onChange={(e) => setNewVarValue(e.target.value)}
                type="password"
              />
            </div>
            <p className="text-xs text-muted-foreground">
              {t("settings.envVar.targetFile", { defaultValue: "目标文件" })}:{" "}
              {defaultShellConfig}
            </p>
          </div>
          <DialogFooter>
            <Button
              variant="ghost"
              onClick={() => setIsAddDialogOpen(false)}
              disabled={isSaving}
            >
              {t("common.cancel")}
            </Button>
            <Button onClick={handleAdd} disabled={isSaving}>
              {isSaving ? (
                <Loader2 className="h-4 w-4 animate-spin mr-2" />
              ) : null}
              {t("common.add")}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      {/* Edit Dialog */}
      <Dialog open={!!editingVar} onOpenChange={() => setEditingVar(null)}>
        <DialogContent className="glass">
          <DialogHeader>
            <DialogTitle>
              {t("settings.envVar.editVar", { defaultValue: "编辑环境变量" })}
            </DialogTitle>
          </DialogHeader>
          <div className="space-y-4 py-4">
            <div className="space-y-2">
              <Label>
                {t("settings.envVar.varName", { defaultValue: "变量名" })}
              </Label>
              <Input value={editingVar?.varName || ""} disabled />
            </div>
            <div className="space-y-2">
              <Label>
                {t("settings.envVar.varValue", { defaultValue: "变量值" })}
              </Label>
              <Input
                value={editVarValue}
                onChange={(e) => setEditVarValue(e.target.value)}
                type="password"
              />
            </div>
          </div>
          <DialogFooter>
            <Button
              variant="ghost"
              onClick={() => setEditingVar(null)}
              disabled={isSaving}
            >
              {t("common.cancel")}
            </Button>
            <Button onClick={handleEdit} disabled={isSaving}>
              {isSaving ? (
                <Loader2 className="h-4 w-4 animate-spin mr-2" />
              ) : null}
              {t("common.save")}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      {/* Delete Confirmation */}
      <Dialog
        open={!!deleteConfirm}
        onOpenChange={() => setDeleteConfirm(null)}
      >
        <DialogContent className="glass">
          <DialogHeader>
            <DialogTitle>
              {t("settings.envVar.deleteConfirmTitle", {
                defaultValue: "删除环境变量",
              })}
            </DialogTitle>
            <DialogDescription>
              {t("settings.envVar.deleteConfirmMessage", {
                name: deleteConfirm?.varName,
                defaultValue: `确定要删除环境变量 "${deleteConfirm?.varName}" 吗？此操作会从配置文件中移除该变量。`,
              })}
            </DialogDescription>
          </DialogHeader>
          <DialogFooter>
            <Button
              variant="ghost"
              onClick={() => setDeleteConfirm(null)}
              disabled={isSaving}
            >
              {t("common.cancel")}
            </Button>
            <Button
              onClick={handleDelete}
              disabled={isSaving}
              className="bg-destructive hover:bg-destructive/90"
            >
              {isSaving ? (
                <Loader2 className="h-4 w-4 animate-spin mr-2" />
              ) : null}
              {t("common.delete")}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </>
  );
}