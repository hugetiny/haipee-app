use crate::services::env_checker::{check_env_conflicts as check_conflicts, EnvConflict};
use crate::services::env_manager::{
    delete_env_vars as delete_vars, get_default_shell_config as get_default_config,
    restore_from_backup, set_env_var as set_var, BackupInfo,
};

/// Check environment variable conflicts for a specific app
#[tauri::command]
pub fn check_env_conflicts(app: String) -> Result<Vec<EnvConflict>, String> {
    check_conflicts(&app)
}

/// Delete environment variables with backup
#[tauri::command]
pub fn delete_env_vars(conflicts: Vec<EnvConflict>) -> Result<BackupInfo, String> {
    delete_vars(conflicts)
}

/// Restore environment variables from backup file
#[tauri::command]
pub fn restore_env_backup(backup_path: String) -> Result<(), String> {
    restore_from_backup(backup_path)
}

/// Get the default shell config file path for the current platform
#[tauri::command]
pub fn get_default_shell_config() -> Result<String, String> {
    Ok(get_default_config())
}

/// Set (add or modify) an environment variable in a shell config file
#[tauri::command]
pub fn set_env_var_command(
    var_name: String,
    var_value: String,
    target_file: Option<String>,
) -> Result<String, String> {
    set_var(var_name, var_value, target_file)
}
